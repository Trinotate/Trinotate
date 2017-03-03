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


=nomore
    
    my $dbproc = &connect_to_db($sqlite_db);

    ## Create ClusterAnalyses table
    
    my $query = "create table ExprClusterAnalyses(cluster_analysis_id, cluster_analysis_name);";
    &RunMod($dbproc, $query);

    $query = "create unique index cluster_analysis_id_idx on ExprClusterAnalyses(cluster_analysis_id)";
    &RunMod($dbproc, $query);

    $query = "create unique index cluster_analysis_name_idx on ExprClusterAnalyses(cluster_analysis_name)";
    &RunMod($dbproc, $query);
    
    
    ## Create Clusters table
    
    $query = "create table ExprClusters(cluster_analysis_id, expr_cluster_id INT, feature_name)";
    &RunMod($dbproc, $query);
    
    $query = "create index expr_clusters_id_name_idx on ExprClusters(cluster_analysis_id, feature_name)";
    &RunMod($dbproc, $query);
    


    ## update the Transcripts table for storing annotations
    $query = "alter table Transcript add column scaffold varchar(100)";
    &RunMod($dbproc, $query);

    $query = "alter table Transcript add column lend int";
    &RunMod($dbproc, $query);

    $query = "alter table Transcript add column rend int";
    &RunMod($dbproc, $query);

    $query = "alter table Transcript add column orient varchar(1) default '+'";
    &RunMod($dbproc, $query);
    

=cut

    
    exit(0);
    


}

