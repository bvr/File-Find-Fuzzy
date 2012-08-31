
package File::Find::Fuzzy::Found;
use Moose;

has match => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str|ArrayRef]',
    handles => {
        match => 'elements',
    },
);

has score => (is => 'ro');

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
