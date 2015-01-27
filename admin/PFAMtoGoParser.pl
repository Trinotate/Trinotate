#!/usr/bin/env perl

use strict;
use warnings;

# orig contrib from Brian Couger

my $usage = "usage: pfamtoGo\n";

my $PFAMtoGO_file = $ARGV[0] or die $usage;

main: {
    open (my $fh, "<", $PFAMtoGO_file) or die $!;
    while (<$fh>) 
	{
        chomp;
        unless (/\w/) { next; }
        if (/^\!/) { next; } # comment line
        my @PFAMtoGOTermsforStorage = split(/\s+/);
        my $PFAMAccession = shift(@PFAMtoGOTermsforStorage); 
        my @SplitAccesion = split(/:/, $PFAMAccession);
        my $PFAMAccesionForPrint= pop(@SplitAccesion);
        my $PFAMDomainName = shift(@PFAMtoGOTermsforStorage);
        my $PFAMtoGoGeneOntologyAcccession = pop(@PFAMtoGOTermsforStorage);
        my $TabJoin = join("\t", $PFAMAccesionForPrint, $PFAMtoGoGeneOntologyAcccession);
        print "$TabJoin\n";
    }
    close $fh;
        
    exit(0);
    
}


