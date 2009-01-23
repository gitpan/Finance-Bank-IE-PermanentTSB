#!/usr/bin/perl

use FindBin;
# load modules from "lib" subdir relative to this script
use lib "$FindBin::Bin/lib"; 
use lib "$FindBin::Bin/cpanlib";

use Finance::Bank::IE::PermanentTSB;
use Data::Dumper;

my %config = (
    "open24numba" => "your open24 #",
    "password" => "your internet password",
    "pan" => "your personal access number",
    "debug" => 1,
    );

my @balance = Finance::Bank::IE::PermanentTSB->check_balance(\%config);

print Dumper(@balance);
foreach my $acc (@balance) {
    printf ("%s ending with %s: %s\n", 
        $acc->{'accname'},
        $acc->{'accno'}, 
        $acc->{'accbal'}
    );
}

my @statement = Finance::Bank::IE::PermanentTSB->account_statement(
    \%config,'Switch Current A/C - 2667','2008/12/01','2008/12/31');

Finance::Bank::IE::PermanentTSB->logoff(\%config);
