#!/usr/bin/env perl

use strict;
use warnings;

use Carp;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);

use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use GO_DAG;

my $usage = <<__EOUSAGE__;

#######################################################################
#
#
#  Required:
#
#  --Trinotate_xls <string>      Trinotate.xls file.
#
#  --gene|G or --trans|T         gene or transcript-mode
#
# Optional:
#
#  --include_ancestral_terms|I     climbs the GO DAG, and incorporates
#                                  all parent terms for an assignment.
#
######################################################################  


__EOUSAGE__

    ;



my $help_flag;
my $trinotate_xls;
my $gene_mode;
my $trans_mode;
my $include_ancestral_terms;

&GetOptions ( 'h' => \$help_flag,
              'Trinotate_xls=s' => \$trinotate_xls,
              'gene|G' => \$gene_mode,
              'trans|T' => \$trans_mode,
              'include_ancestral_terms|I' => \$include_ancestral_terms,
              );


unless ($trinotate_xls && ($gene_mode xor $trans_mode)) {
    die $usage;
}

if (@ARGV) {
    die "Error, unable to parse options: @ARGV ";
}


my $gene_or_trans = ($gene_mode) ? 'gene' : 'trans';



main: {
    
    my $num_lines = `wc -l $trinotate_xls`;
    chomp $num_lines;
    $num_lines =~ s/^\s+//;
    $num_lines =~ /^(\d+)/ or die "Error, cannot parse linecount from $num_lines";
    $num_lines = $1;
    
    print STDERR "Total transcript entries: $num_lines\n";
    

    open (my $fh, $trinotate_xls) or die $!;
    my $header = <$fh>;
    chomp $header;
    my $go_blast_col = -1;
    my $go_pfam_col = -1;
    my @fields = split(/\t/, $header);
    my $col = -1;
    foreach my $field (@fields) {
        $col++;
        if ($field eq 'gene_ontology_blast') {
            $go_blast_col = $col;
        }
        elsif ($field eq 'gene_ontology_pfam') {
            $go_pfam_col = $col;
        }
    }
    unless ($go_blast_col > 0) {
        die "Error, couldn't determine column in report that corresponds to 'gene_ontology_blast' header is: $header ";
    }
    
    my %data;
    my %cache;
    
    my $go_dag;
    if ($include_ancestral_terms) {
        print STDERR "-including ancestral terms in report.\n";
        $go_dag = new GO_DAG();
    }
    
    my $line_counter = 0;

    while (<$fh>) {
        $line_counter++;

        my $pct_done = sprintf("%.2f", $line_counter/$num_lines*100);
        print STDERR "\r[$pct_done] processed.      " if $line_counter % 1000 == 0;
        
        chomp;
        my @x = split(/\t/);
        
        my $feature_id = ($gene_or_trans eq 'gene') ? $x[0] : $x[1];
        
        my $go_info = $x[$go_blast_col];
        if ($go_pfam_col > 0) {
            $go_info .=  '`' . $x[$go_pfam_col];
        }
        my @go_records = split(/\`/, $go_info);
        
        foreach my $go_record (@go_records) {
            my @go_fields = split(/\^/, $go_record);
            my $go_id = shift @go_fields;
            if ($go_id ne ".") {
                
                if (! exists $data{$feature_id}->{$go_id}) {
                
                    $data{$feature_id}->{$go_id} = 1;

                    if ($go_dag && $go_dag->node_exists($go_id)) {
                        my @parent_go_terms;
                        if (my $aref = $cache{$go_id}) {
                            @parent_go_terms = @$aref;
                        }
                        else {
                            @parent_go_terms = $go_dag->get_all_ids_in_path($go_id);
                            $cache{$go_id} = \@parent_go_terms;
                        }
                        foreach my $parent_go (@parent_go_terms) {
                            $data{$feature_id}->{$parent_go} = 1;
                        }
                    }
                }
            }
        }
        
    }
    
    close $fh;

    print STDERR "\n\nDone processing, writing output.\n\n";


    foreach my $feature_id (sort keys %data) {
        my @go_ids = sort keys %{$data{$feature_id}};

        print "$feature_id\t" . join(",", @go_ids) . "\n";
    }

    print STDERR "Finished.\n\n";
    
    
    exit(0);
}



        
            
