#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;

my $usage = "usage: $0 file.eggnog_counts\n\n";


my $inputfile = $ARGV[0] or die $usage;

my $funcat_file = "$FindBin::Bin/../../../resources/eggnog/3.0/COG_KOG_NOG.funccat.txt";
my $descr_file = "$FindBin::Bin/../../../resources/eggnog/3.0/fun.txt";

main: {
        
    my %funcat_mappings = &get_funcat_mappings($funcat_file);
    my %funcat_descriptions = &parse_funcat_descriptions($descr_file);
    
    my ($num_assigned, $num_missing) = (0,0);
    
    my %category_counts;
    open(my $fh, $inputfile) or die "Error, cannot open file $inputfile";
    my $header = <$fh>;
    unless ($header =~ /^eggnog\tcount/) {
        die "Error, not finding expected header for eggnog counts file: $inputfile";
    }
    while (<$fh>) {
        chomp;
        my ($eggnog_acc, $count) = split(/\t/);
        my @acc_pts = split(/\^/);
        my $acc = shift @acc_pts;

        my $category = $funcat_mappings{$acc};
        if ($category && exists $funcat_descriptions{$category}) {
            $num_assigned++;
            my @cats = split(//, $category); # in case mult assigned
            foreach my $cat (@cats) {
                $category_counts{$cat}++;
            }
        }
        else {
            $num_missing++;
        }
    }
    close $fh;

    my $pct_missing = sprintf("%.2f", $num_missing / ($num_missing + $num_assigned) * 100);
    print STDERR "$num_assigned entries found with funcat mappings, $num_missing ($pct_missing\%)lacked assignments\n\n";

    print join("\t", "funcat", "count") . "\n"; # table header 
    foreach my $cat (reverse sort {$category_counts{$a}<=>$category_counts{$b}} keys %category_counts) {

        my $count = $category_counts{$cat};
        print join("\t", $cat, $funcat_descriptions{$cat}, $count) . "\n";
    }
    

    exit(0);
    
}

####
sub get_funcat_mappings {
    my ($file) = @_;

    my %mappings;
    
    open(my $fh, $file) or die "Error, cannot open file $file";
    while (<$fh>) {
        chomp;
        my ($acc, $cat) = split(/\s+/);
        $mappings{$acc} = $cat;
    }
    close $fh;

    return(%mappings);
}

####
sub parse_funcat_descriptions {
    my ($descr_file) = @_;

    my %cat_to_descr;
    
    open (my $fh, $descr_file) or die "Error, cannot open file: $descr_file";
    while (<$fh>) {
        if (/^\s+\[([A-Z])\] (.*)$/) {
            my ($code, $descr) = ($1, $2);
            $cat_to_descr{$code} = $descr;
        }
    }
    close $fh;

    return(%cat_to_descr);
}


    

