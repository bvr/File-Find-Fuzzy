package File::Find::Fuzzy;
# ABSTRACT: The "fuzzy" file finder provides a way for searching a directory tree with only a partial name.

use Moose;
use MooseX::Types::Moose 'Num';
use MooseX::Types::Path::Class;
use Moose::Util::TypeConstraints;

use constant STOP => 1;

subtype 'DirArray'
    => as 'ArrayRef[Path::Class::Dir]';

coerce 'DirArray'
    => from 'ArrayRef[Str]'
    => via { [ map { Path::Class::Dir->new($_) } @$_ ] };

no Moose::Util::TypeConstraints;

has directories => (is => 'rw', isa => 'DirArray', coerce => 1, default => sub { ['.'] });
has ceiling => (is => 'ro', isa => Num, default => 10_000);

has finder => (is => 'ro', isa => 'Path::Class::Rule');
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

    $pattern =~ tr/ //d;
    my @path_parts = split m{/}, $pattern, -1;  # keep also trailing field
    my $pattern_re = '^(.*?)' . (join '(.*?/.*?)', map {
            join '([^/]*?)', map { quotemeta } split //
        } @path_parts) . '(.*?)$';

    # warn $pattern_re;                 # for debugging
    my $file_re = qr/$pattern_re/i;

    for my $file ($self->list_files) {
        if($file->as_foreign('Unix') =~ /$file_re/) {
            last if $cb->(make_match($file)) == STOP;
        }
    }

    # the important question is how to score a match

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
