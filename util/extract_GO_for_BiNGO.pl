#!/usr/bin/env perl

use strict;
use warnings;

use Carp;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);

use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use GO_DAG;
use Data::Dumper;

my $usage = <<__EOUSAGE__;

#######################################################################
#
#  Required:
#
#  --Trinotate_xls <string>      Trinotate.xls file.
#
#  --gene|G or --trans|T         gene or transcript-mode
#
#  --out_prefix <string>         prefix for output files (eg. prefix.BiNGO.Ontolo.txt and prefix.BiNGO.annot.txt
#
######################################################################  


__EOUSAGE__

    ;



my $help_flag;
my $trinotate_xls;
my $gene_mode;
my $trans_mode;
my $out_prefix;

&GetOptions ( 'h' => \$help_flag,
              'Trinotate_xls=s' => \$trinotate_xls,
              'gene|G' => \$gene_mode,
              'trans|T' => \$trans_mode,
              'out_prefix=s' => \$out_prefix,
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

    my $bingo_ontol_file = "$out_prefix.BiNGO.Ontolo.txt";
    my $bingo_annot_file = "$out_prefix.BiNGO.Annot.txt";

    open(my $ontol_ofh, ">$bingo_ontol_file") or die "Error, cannot write to file: $bingo_ontol_file";
    print $ontol_ofh "(curator=GO) (type=process)\n";
    
    open(my $annot_ofh, ">$bingo_annot_file") or die "Error, cannot write to file: $bingo_annot_file";
    print $annot_ofh "(species=mySpecies) (type=Biological Process) (curator=GO)\n";
    
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
    my %seen;
    
    my $go_dag = new GO_DAG();
    
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

                    if ($go_dag->node_exists($go_id)) {
                        $data{$feature_id}->{$go_id} = 1;
                        
                        
                        my $go_node = $go_dag->get_node($go_id);

                        #print STDERR Dumper($go_node);

                        my $namespace = $go_node->{namespace};
                        my $definition = $go_node->{definition};
                        my $name = $go_node->{name};

                        ## Restricting to biological process
                        if ($namespace eq "biological_process") {
                            $go_id =~ s/^GO://;
                            
                            print $annot_ofh "$feature_id\t=$go_id\n";
                            
                            if (! $seen{$go_id}) {
                                print $ontol_ofh join("\t", $go_id, $name) . "\n";
                                $seen{$go_id} = 1;
                            }
                        }
                        
                    }
                    else {
                        print STDERR "-warning, $go_id isn't part of the installed gene ontology obo file... skipping.\n";
                    }
                }
            }
        }
        
    }
    
    close $ontol_ofh;
    close $annot_ofh;

    
    print STDERR "\n\nDone processing.  See output files:  $bingo_ontol_file and $bingo_annot_file\n\n";
    
    exit(0);
    
}



        
            
