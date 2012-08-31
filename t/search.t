
use 5.10.1;
use Test::More;
use Data::Dump;

use File::Find::Fuzzy;

my $finder = File::Find::Fuzzy->new(directories => [ '.' ]);
ok $finder, 'object created';

my @patterns = (
    'dis',
    'rbut',
    't/se',
    'f',
    '',
);

for my $pat (@patterns) {
    $finder->search($pat, sub { say shift->to_string });
    say "---";
}

for my $pat (@patterns) {
    printf "%4d  %s\n", $_->score*1000, $_->to_string
        for $finder->find($pat);
    say "---";
}

done_testing;
