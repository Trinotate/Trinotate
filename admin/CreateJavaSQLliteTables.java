import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class CreateJavaSQLliteTables {
    
    public static void main(String args[]) {

        if (args.length < 1) {
            System.err.println("Name of database to create is required as only parameter");
            System.exit(1);
        }
        
        String database_name = args[0];

        try {
            
            
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:" + database_name);
            Statement stat = conn.createStatement();
            
            // UniprotIndex table
            stat.executeUpdate("create table UniprotIndex(Accession,LinkId,AttributeType);");
            stat.executeUpdate("CREATE INDEX UniprotAccession ON UniprotIndex(Accession)");
            
            // PFAM reference database info
            stat.executeUpdate("create table PFAMreference(pfam_accession, pfam_domainname, pfam_domaindescription,"
                               + "Sequence_GatheringCutOff REAL, Domain_GatheringCutOff REAL, Sequence_TrustedCutOff REAL,"
                               + "Domain_TrustedCutOff REAL, Sequence_NoiseCutOff REAL, Domain_NoiseCutOff REAL);");    
            stat.executeUpdate("CREATE UNIQUE INDEX PFAMUniIndex ON PFAMreference(pfam_accession)");
            
            // TaxonomyIndex table 
            stat.executeUpdate("create table TaxonomyIndex(NCBITaxonomyAccession,TaxonomyValue)");
            stat.executeUpdate("CREATE UNIQUE INDEX NCBIUniIndex ON TaxonomyIndex(NCBITaxonomyAccession)");
            
            // BlastDbase table
            stat.executeUpdate("create table BlastDbase(TrinityID,FullAccession,GINumber,UniprotSearchString,QueryStart REAL,QueryEnd REAL,HitStart REAL,HitEnd REAL,PercentIdentity REAL,Evalue REAL,BitScore REAL, DatabaseSource);");
            stat.executeUpdate("CREATE INDEX TrinityTranscriptID ON BlastDbase(TrinityID)");
            stat.executeUpdate("CREATE INDEX FullAccessionIndex ON BlastDbase(FullAccession)");
            stat.executeUpdate("CREATE INDEX GIIndex ON BlastDbase(GINumber)");
            stat.executeUpdate("CREATE INDEX UniprotSeachStringIndex ON BlastDbase(UniprotSearchString)");
            
            // HMMERDbase table
            stat.executeUpdate("create table HMMERDbase(QueryProtID,pfam_id,HMMERDomain,HMMERTDomainDescription,QueryStartAlign REAL,QueryEndAlign REAL,PFAMStartAlign REAL,PFAMEndAlign REAL,FullSeqEvalue REAL,ThisDomainEvalue REAL,FullSeqScore REAL,FullDomainScore REAL);");
            stat.executeUpdate("CREATE INDEX PFAMQueryID ON HMMERDbase(QueryProtID)");
            stat.executeUpdate("CREATE INDEX PFAMDomainID ON HMMERDbase(pfam_id)");
            
            
            // MaxQuantGFFtoTrinity table (not using yet)
            stat.executeUpdate("create table MaxQuantGFFtoTrinity(MaxQuantQueryID,MaxQuantQueryParentID,MaxQuantProteinMatchStart REAL,MaxQuantProteinMatchend REAL,MaxQuantStrand,MaxQuantTrinityMatchID,MaxQuantscoreFKPMValue REAL,MaxQuantPeptideValue REAL,MaxQuantPeptideScore REAL,MaxQuantExonValue REAL);");
            stat.executeUpdate("CREATE INDEX TrinityID ON MaxQuantGFFtoTrinity(MaxQuantQueryID)");;
            
            // SignalP table
            stat.executeUpdate("create table SignalP(query_prot_id,start REAL,end REAL,score REAL,prediction);");
            stat.executeUpdate("CREATE UNIQUE INDEX QueryID ON SignalP(query_prot_id)");
            
            
            // Trinity transcript structure tables
            stat.executeUpdate("create table Transcript(gene_id, transcript_id, annotation, sequence, scaffold varchar(100), lend INT, rend INT, orient varchar(1) default '+')");
            stat.executeUpdate("CREATE INDEX gene_idx ON Transcript(gene_id)");
            stat.executeUpdate("CREATE UNIQUE INDEX transcript_idx ON Transcript(transcript_id)");
            stat.executeUpdate("CREATE INDEX annot_idx ON Transcript(annotation)");
            
            stat.executeUpdate("create table ORF(orf_id, transcript_id, length REAL, strand, lend, rend, peptide)");
            stat.executeUpdate("CREATE UNIQUE INDEX orf_id_idx ON ORF(orf_id)");
            stat.executeUpdate("CREATE INDEX orf_trans_id_idx ON ORF(transcript_id)");
                        
            // tmhmm table
            stat.executeUpdate("create table tmhmm(queryprotid,Score REAL,PredHel,Topology);");
            stat.executeUpdate("CREATE UNIQUE INDEX QueryIDtmhmm ON tmhmm(queryprotid)");
            
            
            // eggnog table
            stat.executeUpdate("create table eggNOGIndex(eggNOGIndexTerm,eggNOGDescriptionValue)");
            stat.executeUpdate("CREATE UNIQUE INDEX eggNOGUniIndex ON eggNOGIndex(eggNOGIndexTerm)");
            
            
            // gene ontology
            stat.executeUpdate("CREATE TABLE go (id varchar(20), name TEXT, namespace varchar(30), def TEXT)");
            stat.executeUpdate("CREATE UNIQUE INDEX id_idx ON go(id)");

            // pfam2go
            stat.executeUpdate("create table pfam2go(pfam_acc varchar(30), go_id varchar(30))");
            stat.executeUpdate("create index pfam2go_pfam_acc_idx on pfam2go(pfam_acc)");
            
            //---------------
            // add DE stuff
            //---------------

            // Samples
            stat.executeUpdate("CREATE TABLE Samples (sample_id varchar(4), sample_name)");
            stat.executeUpdate("CREATE UNIQUE INDEX sampleid_idx ON Samples(sample_id)");
            stat.executeUpdate("CREATE UNIQUE INDEX samplename_idx ON Samples(sample_name)");

            // Replicates
            stat.executeUpdate("CREATE TABLE Replicates (replicate_id varchar(4), replicate_name, sample_id)");
            stat.executeUpdate("CREATE UNIQUE INDEX rep_id_idx ON Replicates (replicate_id)");
            stat.executeUpdate("CREATE UNIQUE INDEX rep_name_idx ON Replicates (replicate_name)");
            stat.executeUpdate("CREATE INDEX rep_samp_name_idx ON Replicates (sample_id)");

            // Expression
            stat.executeUpdate("CREATE TABLE Expression (feature_name, feature_type, replicate_id, frag_count REAL, fpkm REAL)");
            stat.executeUpdate("CREATE UNIQUE INDEX feat_replicate_idx ON Expression(feature_name, replicate_id)");
            stat.executeUpdate("CREATE INDEX feat_name_type_idx ON Expression(feature_name, feature_type)");
            stat.executeUpdate("CREATE INDEX feature_name_idx ON Expression(feature_name)");
            
            // Diff Expression
            stat.executeUpdate("CREATE TABLE Diff_expression (sample_id_A, sample_id_B, feature_name, feature_type, log_avg_expr REAL, log_fold_change REAL, p_value REAL, fdr REAL)");
            stat.executeUpdate("CREATE UNIQUE INDEX diff_expr_idx ON Diff_expression (sample_id_A, sample_id_B, feature_name)");
            stat.executeUpdate("CREATE INDEX sample_id_type_idx ON Diff_expression (sample_id_A, sample_id_B, feature_type)");
            stat.executeUpdate("CREATE INDEX diff_expr_feat_name_idx ON Diff_expression(feature_name)");
            stat.executeUpdate("CREATE INDEX sample_A_id_idx ON Diff_expression (sample_id_A)");
            stat.executeUpdate("CREATE INDEX sample_B_id_idx ON DIFF_expression (sample_id_B)");
            

            // Expression clusters

            /* Create ClusterAnalyses table */
    
            stat.executeUpdate("create table ExprClusterAnalyses(cluster_analysis_id, cluster_analysis_group, cluster_analysis_name)");
            stat.executeUpdate("create unique index cluster_analysis_id_idx on ExprClusterAnalyses(cluster_analysis_id)");
            stat.executeUpdate("create unique index cluster_group_analysis_names_idx on ExprClusterAnalyses(cluster_analysis_group, cluster_analysis_name)");
                
            /* Create Clusters table */
    
            stat.executeUpdate("create table ExprClusters(cluster_analysis_id, expr_cluster_id INT, feature_name)");
            stat.executeUpdate("create unique index expr_clusters_id_name_idx on ExprClusters(cluster_analysis_id, feature_name)");
            


            /* RNAMmer tables */
            stat.executeUpdate("create table RNAMMERdata(TrinityQuerySequence,Featurestart INTEGER,Featureend INTEGER,Featurescore REAL, FeatureStrand, FeatureFrame, Featureprediction)");
            stat.executeUpdate("CREATE INDEX TrintiyQueryID ON RNAMMERdata(TrinityQuerySequence)");
            

            conn.close();
            
            
        }
        catch (Exception e){//Catch exception if any
            e.printStackTrace();
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        }
    }
}
