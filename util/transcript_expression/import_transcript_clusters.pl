#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use DBI;
use Sqlite_connect;
use Data::Dumper;

my $usage = <<__EOUSAGE__;

######################################################################################################
#
#   usage: $0 -G \$group_name -A \$analysis_name --sqlite Trinotate.sqlite  fileA.matrix fileB.matrix fileC.matrix
# 
######################################################################################################
#
#  --group_name|G <string>   analysis group name (can be common among different analyses)    
#  --analysis_name|A <string>    analysis name (must be unique within an analysis group)
#           
#
#  --sqlite <string>   name of Trinotate sqlite database
#
#  Optional:
#
#  --purge             first, purge all earlier loaded clusters
#
########################################################################################################

__EOUSAGE__

    ;


my $group_name;
my $analysis_name;
my $sqlite_db;
my $purge_flag = 0;

&GetOptions(
    "group_name|G=s" => \$group_name,
    "analysis_name|A=s" => \$analysis_name,
    "sqlite=s" => \$sqlite_db,
    "purge" => \$purge_flag,
    );

unless ($group_name && $analysis_name && $sqlite_db) {
    die $usage;
}

unless (-s $sqlite_db) {
    die "Error, cannot locate $sqlite_db ";
}


my @matrices = @ARGV;
unless (@matrices) {
    die "Error, no matrices to load. ";
}



main: {
    
    my $dbproc = &connect_to_db($sqlite_db);

    my @subcluster_files = @matrices;
        
    if ($purge_flag) {
        my $query = "delete from ExprClusterAnalyses";
        &RunMod($dbproc, $query);
        
        $query = "delete from ExprClusters";
        &RunMod($dbproc, $query);
    }
    

    my $query = "insert into ExprClusterAnalyses(cluster_analysis_group, cluster_analysis_name) values (?,?)";
    &RunMod($dbproc, $query, $group_name, $analysis_name);
    
    $query = "select LAST_INSERT_ROWID()";
    my $row_id = &very_first_result_sql($dbproc, $query);
    
    my $cluster_id = "C$row_id";
    
    $query = "update ExprClusterAnalyses set cluster_analysis_id = ? where rowid = ?";
    &RunMod($dbproc, $query, $cluster_id, $row_id);

    $dbproc->do("PRAGMA synchronous=OFF");
    $dbproc->{AutoCommit} = 0;

    my $subcluster_counter = 0;
    foreach my $subcluster_file (@subcluster_files) {
        $subcluster_counter++;
        open (my $fh, $subcluster_file) or die "Error, cannot open file $subcluster_file";
        print STDERR "-loading $subcluster_file\n";
        my $header = <$fh>;
        my $entry_counter = 0;
        while (<$fh>) {
            chomp;
            my ($feature_name, @vals) = split(/\t/);
            my $query = "insert into ExprClusters (cluster_analysis_id, expr_cluster_id, feature_name) values (?,?,?)";
            &RunMod($dbproc, $query, $cluster_id, $subcluster_counter, $feature_name);
            $entry_counter++;
            print STDERR "\r[$entry_counter] $subcluster_file  ";
        }
        print STDERR "\n";
        close $fh;
        $dbproc->commit;
    }
    

    print STDERR "Done.\n";




    
    $dbproc->disconnect;
    
    exit(0);
    


}

