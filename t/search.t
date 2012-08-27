
use Test::More;
use Data::Dump;

use File::Find::Fuzzy;

my $finder = File::Find::Fuzzy->new(directories => ['t']);

$finder->search('app/bup');

done_testing;
