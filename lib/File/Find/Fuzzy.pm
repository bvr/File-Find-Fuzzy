package File::Find::Fuzzy;
# ABSTRACT: The "fuzzy" file finder provides a way for searching a directory tree with only a partial name.

use Moose;

use Path::Class;
use Path::Class::Rule;
use List::Util      'reduce';
use List::MoreUtils 'natatime';

use File::Find::Fuzzy::Found;

# define types and coercion
use Moose::Util::TypeConstraints;

subtype 'DirArray'
    => as 'ArrayRef[Path::Class::Dir]';

coerce 'DirArray'
    => from 'ArrayRef[Str]'
    => via { [ map { Path::Class::Dir->new($_) } @$_ ] };

no Moose::Util::TypeConstraints;

=attr directories

    my $fff = File::Find::Fuzzy->new(directories => [ 'some_path' ]);
    my @dirs = $fff->directories();

Allows to specify directories to locate files. The value is arrayref of either
strings or L<Path::Class::Dir> objects. Strings are automatically turned into
the objects internally.

By default it looks in current directory.

=cut

has directories => (
    traits  => ['Array'],
    isa     => 'DirArray',
    coerce  => 1,
    default => sub { [] },
    handles => {directories => 'elements'},
);

=attr finder

    my $fff = File::Find::Fuzzy->new(
        finder => Path::Class::Rule->new->skip_dirs('backup')->iname('*.cpp')
    );
    my $fff = File::Find::Fuzzy->new(
        finder => Path::Class::Rule->new->perl_files
    );

A L<Path::Class::Rule> object used to recursively scan the directories for
files. You can specify arbitrarily complex rule to filter out unwanted entries.

By default it looks for all files with skipping of VCS-related files.

=cut

has finder => (
    is      => 'ro',
    isa     => 'Path::Class::Rule',
    default => sub { Path::Class::Rule->new->skip_vcs->file },
);

=attr files

    my @files = $fff->files;

Lazy attribute that is automatically populated with L<Path::Class::File>
objects using L</finder> and L</directories>. You can also specify own
list of files in constructor, effectively skipping all traversal process.

=cut

has files => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Path::Class::File]',
    lazy_build => 1,
    handles => {files => 'elements'},
);

sub _build_files {
    my $self = shift;

    return [ $self->finder->all($self->directories) ];
}

=method search

    $fff->search('path/file', sub {
        my $match = shift;
        say $match->to_string;
    });

Looks for specified pattern in L</files>, running the callback for each
match. The callback is supplied the L<File::Find::Fuzzy::Found> object
that can stringify and has calculated score of the match (higher the
closer match).

=cut

sub search {
    my ($self, $pattern, $cb) = @_;

    # build matching regex
    my ($pattern_re, $path_segments) = _build_pattern_re($pattern);
    my $file_re = qr/$pattern_re/i;

    # find matching files
    for my $file ($self->files) {
        $file->resolve;
        my $filename = '' . $file->as_foreign('Unix');

        if($filename =~ /$file_re/) {
            # scan @- and @+ to get text of all matches
            my @matches
                = map { substr $filename, $-[$_], $+[$_] - $-[$_] } 1..$#-;

            my $total_chars = 0;
            my $inside_chars = 0;
            my @runs;
            my $it = natatime 2, @matches;
            while(my ($not_matched, $matched) = $it->()) {

                # non-matched part push as a text
                if(length $not_matched > 0) {
                    push @runs, $not_matched;
                    $total_chars += length $not_matched;
                }

                # matched either add to previous or create new block
                if(defined $matched) {
                    $inside_chars += length $matched;
                    $total_chars  += length $matched;
                    if(ref $runs[-1]) { $runs[-1][0] .= $matched }
                    else              { push @runs, [ $matched ] }
                }
            }

            # the important question is how to score a match
            my $inside_runs = reduce { $a + (ref($b)?1:0) } 0, @runs;
            my $run_ratio  = $inside_runs == 0 ? 1 : $path_segments / $inside_runs;
            my $char_ratio = $total_chars == 0 ? 1 : $inside_chars  / $total_chars;
            my $score = $run_ratio * $char_ratio;

            $cb->(File::Find::Fuzzy::Found->new( 
                match => \@runs, 
                score => $score,
                file  => $file,
            ));
        }
    }
}

=method find

    my @matches = $fff->find('pattern');

Returns list of matches (L<File::Find::Fuzzy::Found> objects) sorted by score.
The closest matches comes first.

=cut

sub find {
    my ($self, $pattern) = @_;

    my @results = ();
    $self->search($pattern, sub {
        my ($match) = @_;
        push @results, $match;
    });

    return sort { $b->score <=> $a->score } @results;
}

sub _build_pattern_re {
    my $pattern = shift;

    $pattern =~ tr/ //d;

    # if pattern is empty, return /^(.*)$/
    return '^(.*)$' unless $pattern;

    my @path_parts = split m{/}, $pattern, -1;  # keep also trailing field
    my $pattern_re =
        '^(.*?)'                    # start
      . (join '(.*?/.*?)',          # between path parts
            map {
                join '([^/]*?)',    # between expected chars
                                    # each char escaped capture
                    map { "(\Q$_\E)" } split //
                } @path_parts
        )
      . '(.*?)$';                   # end

    return wantarray ? ($pattern_re, scalar @path_parts) : $pattern_re;
}

1;

=head1 SYNOPSIS

    use File::Find::Fuzzy;

    my $finder = File::Find::Fuzzy->new;
    for my $match ($finder->find("app/blogcon")) {
        print $match->to_string,"\n";
    }

=head1 DESCRIPTION

The "fuzzy" file finder provides a way for searching a directory tree with only
a partial name. This is similar to the "cmd-T" feature in TextMate
(L<http://macromates.com>).

In the above example, all files matching "app/blogcon" will be
yielded to the block. The given pattern is reduced to a regular
expression internally, so that any file that contains those
characters in that order (even if there are other characters
in between) will match.

In other words, "app/blogcon" would match any of the following
(parenthesized strings indicate how the match was made):

=for :list
* (app)/controllers/(blog)_(con)troller.rb
* lib/c(ap)_(p)ool/(bl)ue_(o)r_(g)reen_(co)loratio(n)
* test/(app)/(blog)_(con)troller_test.rb

And so forth.

=head1 CREDITS

This modules is B<fuzzy_file_finder>
(L<https://github.com/jamis/fuzzy_file_finder>) adapted to perl. The regex
building, scoring algorithm and parts of documentation are borrowed from that
distribution.

=cut
