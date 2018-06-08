#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use Fasta_reader;

use DBI;
use Sqlite_connect;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);


my $usage = <<__EOUSAGE__;

###########################################################################
#
# Required:
#
#  --sqlite <string>                  Trinotate sqlite database file
#
#  --gene_trans_map <string>          text file indicating  "gene<tab>trans" 
#                                      for each trans-gene relationship.
#
#  --transcript_fasta <string>        transcripts fasta file
#
#  --transdecoder_pep <string>        transcdecoder-generated peptide file
#
# Optional:
#
#  --bulk_load                        for faster loading
#
###########################################################################


__EOUSAGE__


    ;

my $sqlite_db;
my $gene_trans_map_file;
my $transcript_fasta_file;
my $transdecoder_pep_file;
my $help_flag;

my $bulk_loading_flag = 0;

&GetOptions( 

    'sqlite=s' => \$sqlite_db,
    'gene_trans_map=s' => \$gene_trans_map_file,
             'transcript_fasta_file=s' => \$transcript_fasta_file,
             'transdecoder_pep_file=s' => \$transdecoder_pep_file,
             'help|h' => \$help_flag,
             'bulk_load' => \$bulk_loading_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $gene_trans_map_file && $transcript_fasta_file && $transdecoder_pep_file) {
    die $usage;
}

main: {

    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
    
    
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    
    my %trans_to_gene_map;
    {
        print STDERR "-parsing gene/trans map file....";
        open (my $fh, $gene_trans_map_file) or die "Error, cannot locate file: $gene_trans_map_file";
        while (<$fh>) {
            chomp;
            my ($gene, $trans) = split(/\t/);
            $trans_to_gene_map{$trans} = $gene;
        }
        close $fh;
        print STDERR " done.\n";
    }
    

    $dbh->do("PRAGMA synchronous=OFF") or die $!;
    
    $dbh->do("delete from Transcript") or die $!;
    $dbh->do("delete from ORF") or die $!;

    $dbh->{AutoCommit} = 0 unless ($bulk_loading_flag);
    
    my $transcript_table_loading_file = "tmp.Transcript.bulk_load";
    my $transcript_table_ofh;
    
    my $ORF_loading_file = "tmp.ORF.bulk_load";
    my $ORF_table_ofh;

    if ($bulk_loading_flag) {
        open ($transcript_table_ofh, ">$transcript_table_loading_file") or die "Error, cannot write to $transcript_table_loading_file";
        open ($ORF_table_ofh, ">$ORF_loading_file") or die "Error, cannot write to $ORF_loading_file";
    }
    
    
    
    ## insert transcripts
  transcripts: {
      
      print STDERR "-loading Transcripts.\n";

      my $insert_gene_dml = qq {
          INSERT INTO Transcript (gene_id, transcript_id, sequence)
              VALUES (?,?,?)
          };
      my $insert_gene_dsh = $dbh->prepare($insert_gene_dml) unless $bulk_loading_flag;
      
      my $counter = 0;
      my $fasta_reader = new Fasta_reader($transcript_fasta_file);
      while (my $seq_obj = $fasta_reader->next()) {

          $counter++;
          print STDERR "\r[$counter]   " if $counter % 100 == 0;

          my $trans_acc = $seq_obj->get_accession();
          my $sequence = $seq_obj->get_sequence();
      
          my $gene_id = $trans_to_gene_map{$trans_acc} or die "Error, no gene_id for trans: [$trans_acc] ";
          
          if ($bulk_loading_flag) {
              
              # TABLE Transcript(gene_id, transcript_id, annotation, sequence, scaffold varchar(100), lend INT, rend INT, orient varchar(1) default '+')
              print $transcript_table_ofh join("\t", $gene_id, $trans_acc, "", $sequence, "", "", "", "") . "\n";
              
          }
          else {
              $insert_gene_dsh->execute($gene_id, $trans_acc, $sequence) or die $!;
          }

      }
      
      $dbh->commit unless $bulk_loading_flag;

      print STDERR "\ndone.\n";

      $insert_gene_dsh->finish() unless $bulk_loading_flag;
      

  }
    
    
    ## insert proteins
  proteins: {

      print STDERR "-loading ORFs.\n";

      my $insert_ORF_dml = qq {
          INSERT INTO ORF (orf_id, transcript_id, length, strand, lend, rend, peptide) values (?,?,?,?,?,?,?)
          };
      my $insert_ORF_dsh = $dbh->prepare($insert_ORF_dml) unless ($bulk_loading_flag);
      
      ## load peptides
      
      my $fasta_reader = new Fasta_reader($transdecoder_pep_file);
      
      my $counter = 0;
      
      
      while (my $seq_obj = $fasta_reader->next()) {
      
          $counter++;
          print STDERR "\r[$counter]    " if $counter % 100 == 0;
          
          my $header = $seq_obj->get_header();
          my $peptide = $seq_obj->get_sequence();
          
          $header =~ /^(\S+)/ or die "Error, cannot extract accession from $header";
          my $prot_id = $1;
          
          $header =~ /\s+(\S+):(\d+)-(\d+)\(([\+\-])\)/ or die "Error, cannot extract orf coordinates from transcript $header";
          my $transcript_id = $1;
          my $lend = $2;
          my $rend = $3;
          my $strand = $4;
          
          if ($bulk_loading_flag) {
              
              # TABLE ORF(orf_id, transcript_id, length REAL, strand, lend, rend, peptide)
              print $ORF_table_ofh join("\t", $prot_id, $transcript_id, abs($rend - $lend) + 1, $strand, $lend, $rend, $peptide) . "\n";
              
          }
          else {

              $insert_ORF_dsh->execute($prot_id, $transcript_id, abs($rend - $lend) + 1, $strand, $lend, $rend, $peptide) or die $!;
          }
          $counter++;
          if ($counter % 10000 == 0) {
              print STDERR "\r[$counter]   ";
              #$dbh->commit;
          }
      }
      
      $dbh->commit unless $bulk_loading_flag;
      
      print STDERR "\ndone.\n\n";

      $insert_ORF_dsh->finish() unless $bulk_loading_flag;
      
      
        
  }
    

    if ($bulk_loading_flag) {

        close $transcript_table_ofh;
        close $ORF_table_ofh;

        &bulk_load_sqlite($sqlite_db, "Transcript", $transcript_table_loading_file);
        &bulk_load_sqlite($sqlite_db, "ORF", $ORF_loading_file);

        unlink($transcript_table_loading_file, $ORF_loading_file);
        
    }
    else {
        $dbh->disconnect();
    }

    
    print STDERR "\n\nLoading complete..\n\n";
    
    
    
    exit(0);
    
}
