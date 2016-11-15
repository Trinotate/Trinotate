#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use Fasta_reader;
use GTF_utils;
use DBI;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);
use Data::Dumper;

my $usage = <<__EOUSAGE__;

###########################################################################
#
# Required:
#
#  --sqlite <string>       Trinotate sqlite database
#
#  --gtf <string>          GTF annotation file
#
#  --genome_fa <string>    genome fasta file
#
###########################################################################


__EOUSAGE__


    ;

my $help_flag;
my $gtf_file;
my $sqlite_db;
my $genome_fasta_file;

&GetOptions( 'gtf=s' => \$gtf_file,
             'help|h' => \$help_flag,
             'sqlite_db=s' => \$sqlite_db,
             'genome_fa=s' => \$genome_fasta_file,

    );

if ($help_flag) {
    die $usage;
}


unless ($gtf_file && $sqlite_db) {
    die $usage;
}

 

main: {

    unless (-s $sqlite_db) {
        die "Error, cannot find Trinotate.sqlite database.";
    }
    
    
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";


    
    $dbh->do("PRAGMA synchronous=OFF") or die $!;
    
    $dbh->do("delete from Transcript") or die $!;
    $dbh->do("delete from ORF") or die $!;

    $dbh->{AutoCommit} = 0;


    my $gene_obj_indexer_href = {};
    
    my $scaffold_to_genes_href = GTF_utils::index_GTF_gene_objs_from_GTF($gtf_file, $gene_obj_indexer_href);

    my $fasta_reader = new Fasta_reader($genome_fasta_file);

    my %genome_seqs = $fasta_reader->retrieve_all_seqs_hash();
    
    
    ## insert transcripts
    print STDERR "-loading Transcripts and ORFs.\n";
    
    my $insert_gene_dml = qq {
        INSERT INTO Transcript (gene_id, transcript_id, annotation, scaffold, lend, rend, orient, sequence)
            VALUES (?,?,?,?,?,?,?,?)
        };
    my $insert_gene_dsh = $dbh->prepare($insert_gene_dml);
    
    my $insert_orf_dml = qq {
          INSERT INTO ORF (orf_id, transcript_id, length, strand, lend, rend, peptide) 
               VALUES (?,?,?,?,?,?,?)
         };

    my $insert_orf_dsh = $dbh->prepare($insert_orf_dml);
    
    foreach my $scaffold (keys %$scaffold_to_genes_href) {
        
        my @gene_ids = @{$scaffold_to_genes_href->{$scaffold}};
        
        my $chr_seq = $genome_seqs{$scaffold};

        foreach my $gene_id (@gene_ids) {
            
            my $gene_obj = $gene_obj_indexer_href->{$gene_id} or die "Error, cannot locate gene_obj for $gene_id";
            
            $gene_obj->create_all_sequence_types(\$chr_seq);
            
            foreach my $trans_obj ($gene_obj, $gene_obj->get_additional_isoforms()) {

                my $gene_id = $trans_obj->{TU_feat_name};
                my $model_id = $trans_obj->{Model_feat_name};

                my ($lend, $rend) = sort {$a<=>$b} $trans_obj->get_coords();
                my $orient = $trans_obj->get_orientation();
            
                my $annotation = $trans_obj->{com_name};
                
                my $transcript_seq = $trans_obj->get_cDNA_sequence();
                
                print STDERR "-inserting $gene_id, $model_id, $scaffold, $lend, $rend, $orient\n";
                
                eval {
                    $insert_gene_dsh->execute($gene_id, $model_id, $annotation, $scaffold, $lend, $rend, $orient, $transcript_seq) or die $!;
                };

                if ($@) {
                    die "Error, $@\nCannot insert Transcript ($gene_id, $model_id)";
                }

                if (my $protein_seq = $trans_obj->get_protein_sequence()) {
                    my $prot_len = length($protein_seq);
                    my $cds_seq = $trans_obj->get_CDS_sequence();
                    my $cds_rel_start = index($transcript_seq, $cds_seq);
                    if ($cds_rel_start < 0) { 
                        die "Error, cannot map cds within cdna sequence";
                    }
                    my $cds_rel_end = $cds_rel_start + length($cds_seq) - 1;
                    

                    eval {
                        $insert_orf_dsh->execute($model_id, $model_id, $prot_len, '+', $cds_rel_start, $cds_rel_end, $protein_seq);
                    };
                    
                    if ($@) {
                        die "Error, $@\nCannot insert ORF ($model_id)";
                    }
                }
                                
                
            }
        }
    }
    
    print STDERR "\ndone.\n";
    
    $insert_gene_dsh->finish();
      
    $dbh->commit;
    
    
    print STDERR "\n\nLoading complete..\n\n";
    
    $dbh->disconnect();
    
    exit(0);
    
}

