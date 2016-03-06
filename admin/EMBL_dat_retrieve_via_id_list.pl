#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../PerlLib");
use EMBL_parser;
use Data::Dumper;

my $usage = "usage: $0 embl.dat IDs_to_capture.file\n\n";

my $embl_dat_file = $ARGV[0] or die $usage;
my $IDs_to_capture_file = $ARGV[1] or die $usage;

main: {

    my %IDs_to_capture;
    {
        
        print STDERR "-reading in list of IDs to capture ... ";
        open (my $fh, $IDs_to_capture_file) or die "Error, cannot open file $IDs_to_capture_file";
        my $counter = 0;
        while (<$fh>) {
            $counter++;
            my $id = $_;
            $id =~ s/\s//g;
            $IDs_to_capture{$id} = 1;
        }
        close $fh;
        print STDERR " done.  Read $counter ids\n"; 
    }
     
    print STDERR "Capturing entries.\n";
    my $embl_parser = new EMBL_parser($embl_dat_file);

    ## types currently supporting: DEGKT

    my $record_counter = 0;
    
    
    while (my $record = $embl_parser->next()) {
        
        my $ID = $record->{sections}->{ID};
        my @pts = split(/\s+/, $ID);
        $ID = shift @pts;

        my $AC = $record->{sections}->{AC};
        $AC =~ /^(\S+);\s.*/ or die "Error, cannot parse accession value: $AC";
        $AC = $1;
        
        if ($IDs_to_capture{$ID} || $IDs_to_capture{$AC}) {
            print $record->{record};
            delete($IDs_to_capture{$ID});
            delete($IDs_to_capture{$AC});
            $record_counter++;
            print STDERR "\r[$record_counter]    " if $record_counter % 1000 == 0;
            

        }

    }


    if (%IDs_to_capture) {
        open (my $ofh, ">$IDs_to_capture_file.missing.pid$$.text") or die $!;
        my $missing_count = 0;
        foreach my $ID (keys %IDs_to_capture) {
            print $ofh "$ID\n";
            $missing_count++;
        }
        close $ofh;
        
        die "Error, missing records for $missing_count entries, see file: $IDs_to_capture_file.missing.pid$$.text\n\n";
    }
    else {
        print STDERR "All records extracted.\n\n";
    }

    exit(0);
    
}



