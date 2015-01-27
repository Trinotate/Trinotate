#!/usr/bin/env perl

use strict;

my @keep = qw(cleanMe.pl
              EMBL_dat_to_Trinotate_sqlite_resourceDB.pl
              RunMeAdminTest.pl
              notes
EMBL_dat_parser.pl
PFAM_dat_parser.pl



);

my %keep = map { + $_ => 1 } @keep;

foreach my $file (<*>, <testData/*>) {
    if (-f $file && ( ! $keep{$file} ) && $file !~ /\.(java|class|gz)$/) {
        print STDERR "-removing $file\n";
        unlink $file;
    }
}

