
use Test::More;
use Data::Dump;

use File::Find::Fuzzy;

my $finder = File::Find::Fuzzy->new(directories => ['t']);
ok $finder, 'object created';


$finder->search('dir', sub {});

done_testing;
