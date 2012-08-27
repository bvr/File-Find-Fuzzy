use 5.010; use strict; use warnings;
use Test::More;
use Data::Dump;

use File::Find::Fuzzy;

my $finder = File::Find::Fuzzy->new(directories => ['d:/DataDict/787Tools/787bup/trunk']);

my @matches = sort { $a->score <=> $b->score
                  || $a->path  cmp $b->path } $finder->find("bup/app");

for my $match (@matches) {
    say sprintf "[%5d] %s", $match->score * 10000, $match->highlighted_path;
}

done_testing;
