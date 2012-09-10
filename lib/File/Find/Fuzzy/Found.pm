
package File::Find::Fuzzy::Found;
# ABSTRACT: Found item with details about match and score

use Moose;

=attr file

    my $file = $match->file;
    print $file->absolute;

Actual L<Path::Class::File> object for found file.

=cut

has file => (
    is  => 'ro',
    isa => 'Path::Class::File',
);

has match => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str|ArrayRef]',
    handles => {
        match => 'elements',
    },
);

=attr score

    my $score = $match->score;

Floating-point value between 0 .. 1 indicating how close the match is. 
Higher number the better.

=cut

has score => (is => 'ro');

=method to_string

    print $match->to_string;
    print $match->to_string(sub {
        my ($string, $matched) = @_;
        return $string unless $matched;
        return "<b>$string</b>";
    })

Returns string representation of the match. By default matched
portions are enclosed in parens. Optional callback can provide
alternative formatting - it is called with each portion and
a flag that indicates whether it matched the query.

=cut

sub to_string {
    my $self      = shift;
    my $formatter = shift || sub {
        my ($string, $matched) = @_;
        return $string unless $matched;
        return "($string)";
    };

    my $result = '';
    for my $item ($self->match) {
        my $string = ref($item) ? $item->[0] : $item;
        $result .= $formatter->($string, ref($item));
    }
    return $result;
}

__PACKAGE__->meta->make_immutable();
1;

=head1 SYNOPSIS

    use File::Find::Fuzzy;

    my $finder = File::Find::Fuzzy->new;
    for my $match ($finder->find("app/blogcon")) {
        print $match->to_string,"\n";
    }

=head1 DESCRIPTION

A file matched by L<File::Find::Fuzzy>. Can return string representation
of the match (L</to_string>), L</file> and how well the match fit the query (L</score>).

=cut
