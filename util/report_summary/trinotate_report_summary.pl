#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../../PerlLib");
use DelimParser;
use Process_cmd;

my $usage = "\n\n\tusage: $0 Trinotate_report.tsv output_prefix\n\n";

my $trinotate_report_file = $ARGV[0] or die $usage;
my $out_prefix = $ARGV[1] or die $usage;

my $DEBUG = 0;
my $TOP_TAX_LEVEL = 6;


my $UTILDIR = "$FindBin::Bin/util";

main: {

    open(my $fh, $trinotate_report_file) or die "Error, cannot open file $trinotate_report_file";
    my $delim_parser = new DelimParser::Reader($fh, "\t");

    my %TAXONOMY_COUNTER;
    my %SPECIES_COUNTER;

    my %EGGNOG;
    my %KEGG;
    my %PFAM;
    
    while (my $row = $delim_parser->get_row()) {
        
        my $gene_id = $row->{'#gene_id'};
        my $transcript_id = $row->{'transcript_id'};

        my $sprot_Top_BLASTX_hit = $row->{'sprot_Top_BLASTX_hit'} or die "Error, no column name: sprot_Top_BLASTX_hit";
        &extract_taxonomy_info($gene_id, $sprot_Top_BLASTX_hit, \%TAXONOMY_COUNTER, \%SPECIES_COUNTER);

        my ($kegg, $eggnog, $pfam);
        
        if ( ($kegg = $row->{'Kegg'}) && $kegg ne ".") {
            $KEGG{$kegg}->{$gene_id} = 1;
        }
        if ( ($eggnog = $row->{'eggnog'}) && $eggnog ne ".") {
            $EGGNOG{$eggnog}->{$gene_id} = 1;
        }
        if ( ($pfam = $row->{'Pfam'}) && $pfam ne ".") {
            &extract_pfam_info($gene_id, $pfam, \%PFAM);
        }
        
    }
    
    #############################
    ## Report generators
    #############################

    { # write taxonomy info
        my $outfile = "$out_prefix.taxonomy_counts";
        my $header = join("\t", "L1", "L2", "L3", "L4", "L5", "L6", "count");  #FIXME: set L dynamically according to num top levels    
        &nested_hash_to_counts_file(\%TAXONOMY_COUNTER, $outfile, $header);
    }

    { # write species table
        my $outfile = "$out_prefix.species_counts";
        my $header = "species\tcount";
        &nested_hash_to_counts_file(\%SPECIES_COUNTER, $outfile, $header);
    }
    
    { # write eggnog report
        my $outfile = "$out_prefix.eggnog_counts";
        my $header = "eggnog\tcount";
        &nested_hash_to_counts_file(\%EGGNOG, $outfile, $header);

        # generate funcat assignments
        my $cmd = "$UTILDIR/assign_eggnog_funccats.pl $outfile > $outfile.funcats";
        &process_cmd($cmd);
        
    }

    { # write kegg report
        my $outfile = "$out_prefix.kegg.counts";
        my $header = "kegg\tcount";
        &nested_hash_to_counts_file(\%KEGG, $outfile, $header);
    }

    { # write pfam report
        my $outfile = "$out_prefix.pfam.counts";
        my $header = "pfam\tcount";
        &nested_hash_to_counts_file(\%PFAM, $outfile, $header);
    }
    
    
    ## get GO summaries
    &process_cmd("$FindBin::Bin/../extract_GO_assignments_from_Trinotate_xls.pl  --Trinotate_xls $trinotate_report_file -G -I > $out_prefix.GO");
    &process_cmd("$FindBin::Bin/../gene_ontology/Trinotate_GO_to_SLIM.pl $out_prefix.GO > $out_prefix.GO.slim");
    

    ## generate the html report summary:
    &process_cmd("$FindBin::Bin/util/make_cXp_html.pl $out_prefix > $out_prefix.cXp_summary.html");
    
   
    exit(0);
}



#########################
## Data Extractors
#########################


####
sub extract_taxonomy_info {
    my ($gene_id, $sprot_Top_BLASTX_hit, $taxonomy_counter_href, $species_counter_href) = @_;
        
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
        $taxonomy_counter_href->{$top_tax_level}->{$gene_id} = 1;
        $species_counter_href->{$species}->{$gene_id} = 1;
    }
    
    return;
}


####
sub extract_pfam_info {
    my ($gene_id, $pfam_info, $PFAM_href) = @_;

    foreach my $pfam_hit (split(/\`/, $pfam_info)) {
        my @vals = split(/\^/, $pfam_hit);
        my $pfam_domain_name = join("^", @vals[0..2]);
        $PFAM_href->{$pfam_domain_name}->{$gene_id} = 1;
    }
    
    return;
}
    

######################
## utility functions
######################


####
sub nested_hash_to_counts {
    my ($hash_ref) = @_;

    my @info_counts;
    
    foreach my $key_val (keys %$hash_ref) {
        my $count = scalar(keys %{$hash_ref->{$key_val}});
        push (@info_counts, [$key_val, $count]);
    }

    @info_counts = reverse sort {$a->[1]<=>$b->[1]} @info_counts;

    return(@info_counts);
}

####
sub write_counts_to_ofh {
    my ($counts_aref, $ofh) = @_;
    foreach my $count_info (@$counts_aref) {
        my ($key_val, $count) = @$count_info;
        print $ofh "$key_val\t$count\n";
    }
    return;
}


####
sub nested_hash_to_counts_file {
    my ($nested_hash_href, $outfile_name, $header) = @_;
    open(my $ofh, ">$outfile_name")or die "Error, cannot write to $outfile_name";
    print $ofh "$header\n";
    my @counts = &nested_hash_to_counts($nested_hash_href);
    &write_counts_to_ofh(\@counts, $ofh);
    close $ofh;
    return;
}
        
