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
#  --sqlite <string>   name of Trinotate sqlite database
#
###############################################################################################

__EOUSAGE__

    ;



my $sqlite_db;

&GetOptions("sqlite=s" => \$sqlite_db,
    );

unless ($sqlite_db) {
    die $usage;
}


our $SEE = 1;

main: {
    
    
    my $dbproc = &connect_to_db($sqlite_db);

    {
        # purge any earlier cache info:
        my $query = "SELECT name FROM sqlite_master WHERE type = \"table\" and name like \"DEcache%\" ";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my $tablename = $result->[0];
            $query = "drop table $tablename";
            &RunMod($dbproc, $query);
        }
    }


    ## create cache_manager table
    my $query = "create table DEcacheManager (table_name, min_FC, max_FDR);";
    &RunMod($dbproc, $query);
    
    ## generate each of the cache tables.
    my @min_FC_vals = qw( 2 4 8 16 32 64);
    my @max_FDR_vals = qw(0.05 0.001 1e-4 1e-5 1e-10 1e-20 1e-50);


    for (my $i = 0; $i < $#min_FC_vals; $i++) {

        my $min_FC = $min_FC_vals[$i];
        my $min_log2_FC = log($min_FC)/log(2);

        for (my $j = 0; $j < $#max_FDR_vals; $j++) {

            my $max_FDR = $max_FDR_vals[$j];

            my $tablename = "DEcache_minFC_i${i}_maxFDR_j${j}";
            print STDERR "-populating cache table: $tablename\n";

            
            my $query = "insert into DEcacheManager (table_name, min_FC, max_FDR) values (?,?,?)";
            &RunMod($dbproc, $query, $tablename, $min_FC, $max_FDR);
            
            
            $query = "create table $tablename  as "
                . "select distinct feature_name, feature_type "
                . "from Diff_expression d "
                . "where abs(d.log_fold_change) >= $min_log2_FC " 
                . "and d.fdr <= $max_FDR ";
            
            
        
            &RunMod($dbproc, $query);
            
            $query = "CREATE UNIQUE INDEX ${tablename}_idx ON $tablename (feature_name, feature_type)";

            &RunMod($dbproc, $query);
            
        
        }
    
    }
    
    print STDERR "-done.\n\n";
    
    
    exit(0);
    


}

