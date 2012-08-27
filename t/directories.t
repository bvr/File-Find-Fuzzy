
use 5.010; use strict; use warnings;
use Test::More;

use File::Find::Fuzzy;

my $finder = File::Find::Fuzzy->new(directories => ['t']);
is  @{$finder->directories}, 1, 'path set';
diag  $finder->directories->[0]->absolute;
ok -d $finder->directories->[0], 'path exists';

done_testing;
