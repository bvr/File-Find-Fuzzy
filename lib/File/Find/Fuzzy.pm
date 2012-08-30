package File::Find::Fuzzy;
# ABSTRACT: The "fuzzy" file finder provides a way for searching a directory tree with only a partial name.

use Moose;
use MooseX::Types::Moose 'Num';
use MooseX::Types::Path::Class;
use Moose::Util::TypeConstraints;

use List::MoreUtils 'natatime';
use Path::Class::Rule;
use Data::Dump;

use constant STOP => 1;

subtype 'DirArray'
    => as 'ArrayRef[Path::Class::Dir]';

coerce 'DirArray'
    => from 'ArrayRef[Str]'
    => via { [ map { Path::Class::Dir->new($_) } @$_ ] };

no Moose::Util::TypeConstraints;

has ceiling => (is => 'ro', isa => Num, default => 10_000);

has directories => (
    is      => 'rw',
    traits  => ['Array'],
    isa     => 'DirArray',
    coerce  => 1,
    default => sub { ['.'] },
    handles => {list_directories => 'elements'},
);

has finder => (
    is      => 'ro',
    isa     => 'Path::Class::Rule',
    default => sub { Path::Class::Rule->new->skip_vcs->file },
);

has files => (
    is      => 'rw',
    traits  => ['Array'],
    isa     => 'ArrayRef[Path::Class::File]',
    lazy_build => 1,
    handles => {list_files => 'elements'},
);

sub _build_files {
    my $self = shift;

    return [ $self->finder->all($self->list_directories) ];
}

sub search {
    my ($self, $pattern, $cb) = @_;

    # build matching regex
    my $pattern_re = _build_pattern_re($pattern);
    warn $pattern_re,"\n";
    my $file_re = qr/$pattern_re/i;

    # find matching files
    for my $file ($self->list_files) {
        my $filename = '' . $file->as_foreign('Unix');
        warn "testing $filename\n";
        if($filename =~ /$file_re/) {
            # scan @- and @+ to get text of all matches
            my @matches = map { substr $filename, $-[$_], $+[$_] - $-[$_] } 1..$#-;

            # dd { $filename => \@matches };

            my $it = natatime 2, @matches;

            my @runs;
            while(my ($not_matched, $matched) = $it->()) {

                # non-matched part push as a text
                push @runs, $not_matched
                    if length $not_matched > 0;

                # matched either add to previous or create new block
                if(defined $matched) {
                    if(ref $runs[-1]) { $runs[-1][0] .= $matched }
                    else              { push @runs, [ $matched ] }
                }
            }

            dd \@runs;

            # the important question is how to score a match
            # $run_ratio =
            # my $score = $run_ratio * $char_ratio;

            # last if $cb->($file) == STOP;
        }
    }


    warn "----\n";
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

    return $pattern_re;
}

sub find {
    my ($self, $pattern, $max) = @_;

    my @results = ();
    $self->search($pattern, sub {
        my ($match) = @_;
        push @results, $match;

        return STOP if defined $max && $max-- < 0;
    });

    return @results;
}

sub make_match {

}

1;


=head2 Overview of functionality

 - directories to start with
 - array of ignores - list of patterns to skip during follow_tree
 - determines shared prefix

 - rescan (clears list of files and scan all roots)
   - uses follow_tree(dir) ... recursive descent (use Path::Class::Rule instead)

 - search call a block with found item

 - find a shortcut to search, returning results in an array

 - rather important method make_pattern(string), which builds a RE string

=head1 SYNOPSIS

    use File::Find::Fuzzy;

    my $finder = File::Find::Fuzzy->new;
    for my $match ($finder->search("app/blogcon")) {
        print $match->highlighted_path,"\n";
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

=cut
