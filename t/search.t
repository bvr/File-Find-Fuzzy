
use Test::More;
use Data::Dump;

use File::Find::Fuzzy;

my $finder = File::Find::Fuzzy->new(directories => ['.']);
ok $finder, 'object created';

$finder->search('dir', sub {});
$finder->search('rbut', sub {});
$finder->search('t/se', sub {});
$finder->search('f', sub {});
$finder->search('', sub {});

done_testing;
