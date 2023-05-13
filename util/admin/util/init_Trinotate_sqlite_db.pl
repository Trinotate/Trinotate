#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../../PerlLib");
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
###########################################################################


__EOUSAGE__


    ;

my $sqlite_db;
my $help_flag;


&GetOptions( 

    'sqlite=s' => \$sqlite_db,
    'help|h' => \$help_flag,
    
    );

if ($help_flag) {
    die $usage;
}

unless ($sqlite_db) {
    die $usage;
}

main: {

    if (-s $sqlite_db) {
        die "\n\nError, the $sqlite_db database file already exists. Please remove it or rename it before proceeding with initialization.\n\n";
    }
    
    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";

    ## UniprotIndex table
    &RunMod($dbproc, "create table UniprotIndex(Accession,LinkId,AttributeType);");
    &RunMod($dbproc, "CREATE INDEX UniprotAccession ON UniprotIndex(Accession)");
    
    ## PFAM reference database info
    &RunMod($dbproc, "create table PFAMreference(pfam_accession, pfam_domainname, pfam_domaindescription,"
            . "Sequence_GatheringCutOff REAL, Domain_GatheringCutOff REAL, Sequence_TrustedCutOff REAL,"
            . "Domain_TrustedCutOff REAL, Sequence_NoiseCutOff REAL, Domain_NoiseCutOff REAL);");    
    &RunMod($dbproc, "CREATE UNIQUE INDEX PFAMUniIndex ON PFAMreference(pfam_accession)");
    
    ## TaxonomyIndex table 
    &RunMod($dbproc, "create table TaxonomyIndex(NCBITaxonomyAccession,TaxonomyValue)");
    &RunMod($dbproc, "CREATE UNIQUE INDEX NCBIUniIndex ON TaxonomyIndex(NCBITaxonomyAccession)");
    
    ## BlastDbase table
    &RunMod($dbproc, "create table BlastDbase(TrinityID,FullAccession,GINumber,UniprotSearchString,QueryStart REAL,QueryEnd REAL,HitStart REAL,HitEnd REAL,PercentIdentity REAL,Evalue REAL,BitScore REAL, DatabaseSource);");
    &RunMod($dbproc, "CREATE INDEX TrinityTranscriptID ON BlastDbase(TrinityID)");
    &RunMod($dbproc, "CREATE INDEX FullAccessionIndex ON BlastDbase(FullAccession)");
    &RunMod($dbproc, "CREATE INDEX GIIndex ON BlastDbase(GINumber)");
    &RunMod($dbproc, "CREATE INDEX UniprotSeachStringIndex ON BlastDbase(UniprotSearchString)");
    
    ## HMMERDbase table
    &RunMod($dbproc, "create table HMMERDbase(QueryProtID,pfam_id,HMMERDomain,HMMERTDomainDescription,QueryStartAlign REAL,QueryEndAlign REAL,PFAMStartAlign REAL,PFAMEndAlign REAL,FullSeqEvalue REAL,ThisDomainEvalue REAL,FullSeqScore REAL,FullDomainScore REAL);");
    &RunMod($dbproc, "CREATE INDEX PFAMQueryID ON HMMERDbase(QueryProtID)");
    &RunMod($dbproc, "CREATE INDEX PFAMDomainID ON HMMERDbase(pfam_id)");
    
    
    ## MaxQuantGFFtoTrinity table (not using yet)
    #&RunMod($dbproc, "create table MaxQuantGFFtoTrinity(MaxQuantQueryID,MaxQuantQueryParentID,MaxQuantProteinMatchStart REAL,MaxQuantProteinMatchend REAL,MaxQuantStrand,MaxQuantTrinityMatchID,MaxQuantscoreFKPMValue REAL,MaxQuantPeptideValue REAL,MaxQuantPeptideScore REAL,MaxQuantExonValue REAL);");
    #&RunMod($dbproc, "CREATE INDEX TrinityID ON MaxQuantGFFtoTrinity(MaxQuantQueryID)");;
    
    ## SignalP table
    &RunMod($dbproc, "create table SignalP(query_prot_id,start REAL,end REAL,score REAL,prediction);");
    &RunMod($dbproc, "CREATE UNIQUE INDEX QueryID ON SignalP(query_prot_id)");
    
    
    ## Trinity transcript structure tables
    &RunMod($dbproc, "create table Transcript(gene_id, transcript_id, annotation, sequence, scaffold varchar(100), lend INT, rend INT, orient varchar(1) default '+')");
    &RunMod($dbproc, "CREATE INDEX gene_idx ON Transcript(gene_id)");
    &RunMod($dbproc, "CREATE UNIQUE INDEX transcript_idx ON Transcript(transcript_id)");
    &RunMod($dbproc, "CREATE INDEX annot_idx ON Transcript(annotation)");
    
    &RunMod($dbproc, "create table ORF(orf_id, transcript_id, length REAL, strand, lend, rend, peptide)");
    &RunMod($dbproc, "CREATE UNIQUE INDEX orf_id_idx ON ORF(orf_id)");
    &RunMod($dbproc, "CREATE INDEX orf_trans_id_idx ON ORF(transcript_id)");
    
    ## tmhmm table
    &RunMod($dbproc, "create table tmhmm(queryprotid,Score REAL,PredHel,Topology);");
    &RunMod($dbproc, "CREATE UNIQUE INDEX QueryIDtmhmm ON tmhmm(queryprotid)");
    
    
    ## eggnog table
    &RunMod($dbproc, "create table eggNOGIndex(eggNOGIndexTerm,eggNOGDescriptionValue)");
    &RunMod($dbproc, "CREATE UNIQUE INDEX eggNOGUniIndex ON eggNOGIndex(eggNOGIndexTerm)");
    
    
    ## gene ontology FULL
    &RunMod($dbproc, "CREATE TABLE go (id varchar(20), name TEXT, namespace varchar(30), def TEXT)");
    &RunMod($dbproc, "CREATE UNIQUE INDEX id_idx ON go(id)");


    ## gene ontology SLIM
    &RunMod($dbproc, "CREATE TABLE go_slim (id varchar(20), name TEXT, namespace varchar(30), def TEXT)");
    &RunMod($dbproc, "CREATE UNIQUE INDEX slim_id_idx ON go_slim(id)");

    ## go slim to go id mappings:
    &RunMod($dbproc, "CREATE TABLE go_slim_mapping (go_id varchar(20), slim_id varchar(20))");
    &RunMod($dbproc, "CREATE INDEX mapped_go_id_idx ON go_slim_mapping(go_id)");
    &RunMod($dbproc, "CREATE INDEX mapped_slim_id_idx ON go_slim_mapping(slim_id)");
    &RunMod($dbproc, "CREATE UNIQUE INDEX mapped_slim_ids_idx ON go_slim_mapping(go_id, slim_id)");
    
    
    ## pfam2go
    &RunMod($dbproc, "create table pfam2go(pfam_acc varchar(30), go_id varchar(30))");
    &RunMod($dbproc, "create index pfam2go_pfam_acc_idx on pfam2go(pfam_acc)");
    
    ##---------------
    ## add DE stuff
    ##/
    
    ##/---------------
    
    ## Samples
    &RunMod($dbproc,"CREATE TABLE Samples (sample_id varchar(4), sample_name)");
    &RunMod($dbproc,"CREATE UNIQUE INDEX sampleid_idx ON Samples(sample_id)");
    &RunMod($dbproc,"CREATE UNIQUE INDEX samplename_idx ON Samples(sample_name)");
    
    ## Replicates
    &RunMod($dbproc,"CREATE TABLE Replicates (replicate_id varchar(4), replicate_name, sample_id)");
    &RunMod($dbproc,"CREATE UNIQUE INDEX rep_id_idx ON Replicates (replicate_id)");
    &RunMod($dbproc,"CREATE UNIQUE INDEX rep_name_idx ON Replicates (replicate_name)");
    &RunMod($dbproc,"CREATE INDEX rep_samp_name_idx ON Replicates (sample_id)");
    
    ## Expression
    &RunMod($dbproc,"CREATE TABLE Expression (feature_name, feature_type, replicate_id, frag_count REAL, fpkm REAL)");
    &RunMod($dbproc,"CREATE UNIQUE INDEX feat_replicate_idx ON Expression(feature_name, replicate_id)");
    &RunMod($dbproc,"CREATE INDEX feat_name_type_idx ON Expression(feature_name, feature_type)");
    &RunMod($dbproc,"CREATE INDEX feature_name_idx ON Expression(feature_name)");
    
    ## Diff Expression
    &RunMod($dbproc,"CREATE TABLE Diff_expression (sample_id_A, sample_id_B, feature_name, feature_type, log_avg_expr REAL, log_fold_change REAL, p_value REAL, fdr REAL)");
    &RunMod($dbproc,"CREATE UNIQUE INDEX diff_expr_idx ON Diff_expression (sample_id_A, sample_id_B, feature_name)");
    &RunMod($dbproc,"CREATE INDEX sample_id_type_idx ON Diff_expression (sample_id_A, sample_id_B, feature_type)");
    &RunMod($dbproc,"CREATE INDEX diff_expr_feat_name_idx ON Diff_expression(feature_name)");
    &RunMod($dbproc,"CREATE INDEX sample_A_id_idx ON Diff_expression (sample_id_A)");
    &RunMod($dbproc,"CREATE INDEX sample_B_id_idx ON DIFF_expression (sample_id_B)");
    
    
    ## Expression clusters
    
    # Create ClusterAnalyses table
        
    &RunMod($dbproc,"create table ExprClusterAnalyses(cluster_analysis_id, cluster_analysis_group, cluster_analysis_name)");
    &RunMod($dbproc,"create unique index cluster_analysis_id_idx on ExprClusterAnalyses(cluster_analysis_id)");
    &RunMod($dbproc,"create unique index cluster_group_analysis_names_idx on ExprClusterAnalyses(cluster_analysis_group, cluster_analysis_name)");
    
    # Create Clusters table
    
    &RunMod($dbproc,"create table ExprClusters(cluster_analysis_id, expr_cluster_id INT, feature_name)");
    &RunMod($dbproc,"create unique index expr_clusters_id_name_idx on ExprClusters(cluster_analysis_id, feature_name)");
    
    # RNAMMmer table
    &RunMod($dbproc,"create table RNAMMERdata(TrinityQuerySequence,Featurestart INTEGER,Featureend INTEGER,Featurescore REAL, FeatureStrand, FeatureFrame, Featureprediction)");
    &RunMod($dbproc,"CREATE INDEX TrintiyQueryID ON RNAMMERdata(TrinityQuerySequence)");
    
    # Infernal table
    &RunMod($dbproc,"create table Infernal(query_acc, target_name, rfam_acc, clan_name, region_start, region_end, strand, score, evalue)");
    &RunMod($dbproc,"CREATE INDEX InfernalQueryIdx ON Infernal(query_acc)");
    

    # Eggnog-mapper table:
    &RunMod($dbproc,"create table EggnogMapper(query_acc, seed_ortholog, evalue, score, eggNOG_OGs, max_annot_lvl, COG_category, Description, Preferred_name, GOs, EC, KEGG_ko, KEGG_Pathway, KEGG_Module, KEGG_Reaction, KEGG_rclass, BRITE, KEGG_TC, CAZy, BiGG_Reaction, PFAMs)")
    &RunMod($dbproc,"CREATE INDEX EggMapperQueryIdx ON EggnogMapper(query_acc)");
        
    print STDERR "-done creating database $sqlite_db\n\n";
    
    
    
    exit(0);
    
}
