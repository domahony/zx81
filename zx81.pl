#!/usr/bin/perl -w

use strict;
use diagnostics;
use ZX81;

binmode(STDIN);

my $MEM;
while (<STDIN>) {
    $MEM .= $_;
}

my $zx81 = ZX81->new($MEM);

$zx81->start();
