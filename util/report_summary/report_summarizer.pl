#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../../PerlLib");
use DelimParser;

my $usage = "\n\n\tusage: $0 Trinotate_report.tsv  out_prefix\n\n";

my $trinotate_report_file = $ARGV[0] or die $usage;
my $out_prefix = $ARGV[1] or die $usage;

my $DEBUG = 1;
my $TOP_TAX_LEVEL = 6;

main: {


    open(my $fh, $trinotate_report_file) or die "Error, cannot open file $trinotate_report_file";
    my $delim_parser = new DelimParser::Reader($fh, "\t");

    my %TAXONOMY_COUNTER;
    my %SPECIES_COUNTER;
    
    while (my $row = $delim_parser->get_row()) {
        
        my $gene_id = $row->{'#gene_id'};
        my $transcript_id = $row->{'transcript_id'};

        my $sprot_Top_BLASTX_hit = $row->{'sprot_Top_BLASTX_hit'} or die "Error, no column name: sprot_Top_BLASTX_hit";
        &extract_taxonomy_info($sprot_Top_BLASTX_hit, \%TAXONOMY_COUNTER, \%SPECIES_COUNTER);
        
        
    }
    
    ## Reporting
    &write_taxonomy_table(\%TAXONOMY_COUNTER);
    
    &write_species_table(\%SPECIES_COUNTER);

    

    exit(0);
}



####
sub extract_taxonomy_info {
    my ($sprot_Top_BLASTX_hit, $taxonomy_counter_href, $species_counter_href) = @_;
        
    if ($sprot_Top_BLASTX_hit ne '.') {
        my @pts = split(/\^/, $sprot_Top_BLASTX_hit);
        my $taxonomy = pop @pts;
        my @tax_levels = split(/;\s*/, $taxonomy);
        my $species = pop @tax_levels;
        my @top_tax_levels = @tax_levels[0..($TOP_TAX_LEVEL-1)];
        for my $level (@top_tax_levels) {
            if (! defined $level) {
                $level = "NA";
            }
        }
        
        my $top_tax_level = join("\t", @top_tax_levels);
        print STDERR "$top_tax_level -> $species\n" if $DEBUG;
        $taxonomy_counter_href->{$top_tax_level}++;
        $species_counter_href->{$species}++;
    }
    
    return;
}


####
sub write_taxonomy_table {
    my ($taxonomy_counter_href) = @_;
    
    my $outfile = "$out_prefix.taxonomy_counts";
    open(my $ofh, ">$outfile") or die "Error, cannot write to $outfile";
    
    print $ofh join("\t", "L1", "L2", "L3", "L4", "L5", "L6", "count") . "\n";  #FIXME: set L dynamically according to num top levels
    
    foreach my $taxonomy_val (reverse sort {$taxonomy_counter_href->{$a}<=>$taxonomy_counter_href->{$b}} keys %$taxonomy_counter_href) {
        my $count = $taxonomy_counter_href->{$taxonomy_val};

        print $ofh "$taxonomy_val\t$count\n";
    }

    close $ofh;

    return;
}

        
####
sub write_species_table {
    my ($species_counter_href) = @_;

    my $outfile = "$out_prefix.species_counts";
    open(my $ofh, ">$outfile") or die "Error, cannot write to $outfile";
    print $ofh join("\t", "species", "count") . "\n";
    
    foreach my $species (reverse sort {$species_counter_href->{$a} <=> $species_counter_href->{$b}} keys %$species_counter_href) {
        print $ofh join("\t", $species, $species_counter_href->{$species}) . "\n";
    }

    return;
}
    
    
