#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Getopt::Long qw(:config no_ignore_case bundling);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use DBI;
use Sqlite_connect;
use Data::Dumper;

my $usage = <<__EOUSAGE__;

###############################################################################################
#
#  --annot <string>      Annotation format is simply:
#           
#                        gene_id (tab) transcript_id (tab) free text till end of line as annot
#                      
#
#
#  --sqlite <string>   name of Trinotate sqlite database
#
###############################################################################################

__EOUSAGE__

    ;



my $annot_file;
my $sqlite_db;

&GetOptions("annot=s" => \$annot_file,
            "sqlite=s" => \$sqlite_db,
    );

unless ($annot_file && $sqlite_db) {
    die $usage;
}


main: {
    
    my $dbproc = &connect_to_db($sqlite_db);

    ## drop table if it exists
    eval {
        
        my $query = "drop table Annotation";
        &RunMod($dbproc, $query);
    };
    
    ## Create table
    
    my $query = "create table Annotation (gene_id, transcript_id, annot);";
    &RunMod($dbproc, $query);

    $query = "create index annot_gene_id_idx on Annotation(gene_id)";
    &RunMod($dbproc, $query);

    $query = "create index annot_trans_id_idx on Annotation(transcript_id)";
    &RunMod($dbproc, $query);
    
    
    ## Populate it
    
    $dbproc->do("PRAGMA synchronous=OFF");
    $dbproc->{AutoCommit} = 0;
    

    my $counter = 0;
    
    $query = "insert into Annotation(gene_id, transcript_id, annot) values (?,?,?)";
    open (my $fh, $annot_file) or die "Error, cannot open file $annot_file";
    while (<$fh>) {
        if (/^\#/) { next; } # ignoring header line or comments
        my ($gene_id, $trans_id, $annot) = split(/\t/, $_, 3);

        if ($trans_id =~ /^(comp\d+_c\d+_seq\d+)/) {
            ## trinity specific
            $trans_id = $1;
        }
        
        &RunMod($dbproc, $query, $gene_id, $trans_id, $annot);
        
        $counter++;
        if ($counter % 1000 == 0) {
            $dbproc->commit;
            print STDERR "\r[$counter]    ";
        }
    }
    close $fh;

    $dbproc->commit;
    print STDERR "\n\ndone.\n";
    
    
    $dbproc->disconnect;
    
    exit(0);
    


}

