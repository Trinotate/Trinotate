#!/usr/bin/env perl

use strict;
use warnings;

if ( -e "Trinotate.sqlite") {
    unlink("Trinotate.sqlite") or die $!;
}

foreach my $file (<testData/*.gz>) {
    my $unzipped = $file;
    $unzipped =~ s/\.gz$//;
    unless (-s $unzipped) {
        system("gunzip -c $file > $unzipped");
    }
}

system("./EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite Trinotate.test.sqlite --create --embl_dat testData/UniProtTestdata.file --pfam testData/pfam.sample --eggnog testData/eggnog.sample --go_obo testData/go.obo.sample");





