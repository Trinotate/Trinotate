#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Text::NSP::Measures::2D::Fisher::twotailed;
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use Sqlite_connect;
use GO_DAG;


main: {

    
    my $dbproc = &connect_to_db("Trinotate.sqlite");

    print STDERR "-getting cluster analysis names\n";
    my @analysis_cluster_info = &get_cluster_analyses($dbproc);
    
    unless (@analysis_cluster_info) {
        die "Error, no analyses stored for gene clusterings";
    }

    &analyze_pfam_enrichment($dbproc, @analysis_cluster_info);
    
    &analyze_GO_enrichment($dbproc, @analysis_cluster_info);
    
    
    exit(0);
}

####
sub analyze_pfam_enrichment {
    my ($dbproc, @analysis_cluster_info) = @_;

    ## only do analysis based on genes.
    print STDERR "-getting pfam/gene data\n";
    my ($pfam_domains_to_genes_href, $genes_to_pfam_domains_href) = &get_pfam_gene_data($dbproc);
    
    
    my $total_num_genes = scalar(keys %$genes_to_pfam_domains_href);
    

    foreach my $analysis_result_aref (@analysis_cluster_info) {
        my ($cluster_analysis_id, $cluster_analysis_name) = @$analysis_result_aref;
        
        print STDERR "-processing analysis: $cluster_analysis_name, id: $cluster_analysis_id\n";

        my %expr_cluster_id_to_genes = &get_gene_clusters($dbproc, $cluster_analysis_id);
        
        
        foreach my $expr_cluster_id (keys %expr_cluster_id_to_genes) {
            
            print STDERR "\texamining $cluster_analysis_name cluster_id: $expr_cluster_id\n";
            
            my @genes = @{$expr_cluster_id_to_genes{$expr_cluster_id}};
            my $total_genes_in_cluster = scalar(@genes);

            my %genes_in_cluster = map { + $_ => 1 } @genes;

            ## get list of domains
            my %domains;
            foreach my $gene (@genes) {
                if (my $domains_href = $genes_to_pfam_domains_href->{$gene}) {
                    foreach my $domain (keys %$domains_href) { 
                        $domains{$domain} = 1;
                    }
                }
            }
            
            ## examine enrichment
            
            foreach my $domain (keys %domains) {
             
                my $summary_struct = &do_enrichment_test($domain, \@genes, $genes_to_pfam_domains_href, $pfam_domains_to_genes_href);
                
                my $Pval = $summary_struct->{Pval};
                my $enrichment = $summary_struct->{enrichment};
                
                if ($Pval <= 0.05) {
                    print join("\t", $expr_cluster_id, $domain, $Pval, $enrichment) . "\n";
                }
            }
            
        }
    
    }
    

}


sub do_enrichment_test {
    my ($feature, $genes_subset_aref, $gene_to_features_href, $feature_to_genes_href) = @_;
    
    my $total_num_genes = scalar(keys %$gene_to_features_href);
    my $total_subset_genes = scalar(@$genes_subset_aref);
    
    my @all_genes_with_feature = keys %{$feature_to_genes_href->{$feature}};
    my $total_genes_with_feature = scalar(@all_genes_with_feature);
    
    my %genes_subset = map { + $_ => 1 } @$genes_subset_aref;
    
    my @subset_genes_with_feature = grep { $genes_subset{$_} } @all_genes_with_feature;
    my $total_subset_genes_with_feature = scalar(@subset_genes_with_feature);
    
    my $ratio_all_genes_with_feature = $total_genes_with_feature / $total_num_genes;
    
    my $ratio_genes_in_cluster_with_feature = $total_subset_genes_with_feature / $total_subset_genes;
    
    my $enrichment = $ratio_all_genes_with_feature/$ratio_genes_in_cluster_with_feature;
    
    ## do Fishers Exact Test
    my $n11 = $total_subset_genes_with_feature;
    my $n1p = $total_genes_with_feature;
    my $np1 = $total_subset_genes;
    my $npp = $total_num_genes;
    
    my $twotailed_value = calculateStatistic(n11 => $n11,
                                             n1p => $n1p,
                                             np1 => $np1,
                                             npp => $npp);
    
    if (my $errorCode = getErrorCode()) {
        $twotailed_value = "NA";
        print STDERR $errorCode . "-" . getErrorMessage() . "\n";
    }
    else {
        $twotailed_value = sprintf("%.2e", $twotailed_value);
    }
    
    #print join("\t", $feature, $twotailed_value) . "\n";
    
    my $summary = { Pval => $twotailed_value,
                    total_num_genes => $total_num_genes,
                    total_genes_with_feature => $total_genes_with_feature,
                    total_subset_genes => $total_subset_genes,
                    total_subset_genes_with_feature => $total_subset_genes_with_feature,
                    enrichment => $enrichment,
    };
    
    return ($summary);
}

####
sub get_cluster_analyses {
    my ($dbproc) = @_;
    
    # get list of different analyses
    
    my $query = "select cluster_analysis_id, cluster_analysis_name from ExprClusterAnalyses";
    my @results = &do_sql_2D($dbproc, $query);
    
    return (@results);
}
        



####
sub get_pfam_gene_data {
    my ($dbproc) = @_;

    my %domain_names;

    ## get the pfam domain info
    print STDERR "\t-getting pfam domain descriptions\n";
    my $query = "select pfam_accession, pfam_domainname, pfam_domaindescription from PFAMreference";
    my @results = &do_sql_2D($dbproc, $query);
    foreach my $result (@results) {
        my ($pfam_id, $hmmer_domain, $description) = @$result;
        $domain_names{$pfam_id} = "$pfam_id $hmmer_domain $description";
    }


    my %pfam_domains_to_genes;
    my %genes_to_pfam_domains;
    
    print STDERR "\t-retrieving all pfam hits above domain trusted cutoff.\n";
    ## get all the hits
    $query = "select T.gene_id, H.pfam_id "
        . " from Transcript T, HMMERDbase H, ORF O, PFAMreference p "
        . " where H.QueryProtID = O.orf_id "
        . " and O.transcript_id = T.transcript_id "
        . " and H.pfam_id = p.pfam_accession " 
        . " and H.FullDomainScore >= p.Domain_TrustedCutOff ";

    @results = &do_sql_2D($dbproc, $query);

    unless (@results) {
        die "Error, no pfam hits found above trusted cutoff via query:\n$query\n";
    }

    foreach my $result (@results) {
        
        my ($gene_id, $pfam_id) = @$result;
     
        #print join("\t", $gene_id, $pfam_id) . "\n";
   
        $pfam_domains_to_genes{$pfam_id}->{$gene_id} = 1;
        $genes_to_pfam_domains{$gene_id}->{$pfam_id} = 1;

    }

    return(\%pfam_domains_to_genes, \%genes_to_pfam_domains);

}


####
sub get_gene_clusters {
    my ($dbproc, $cluster_analysis_id) = @_;

    my $query = "select E.expr_cluster_id, T.gene_id "
        . " from Transcript T, ExprClusters E "
        . " where E.cluster_analysis_id = ? "
        . " and ( E.feature_name = T.gene_id OR E.feature_name = T.transcript_id ) ";

    my @results = &do_sql_2D($dbproc, $query, $cluster_analysis_id);

    my %cluster_id_to_genes;
    foreach my $result (@results) {
        my ($expr_cluster_id, $gene_id) = @$result;
        push (@{$cluster_id_to_genes{$expr_cluster_id}}, $gene_id);
    }

    return(%cluster_id_to_genes);
}

####
sub analyze_GO_enrichment {
    my ($dbproc, @analysis_cluster_info) = @_;

    ## only doing analysis based on genes
    print STDERR "-getting gene ontology data\n";
    my ($go_to_genes_href, $genes_to_go_href, $go_dag) = &get_GO_gene_data($dbproc);
    
    my $total_genes_with_GO_annots = scalar(keys %$genes_to_go_href);
    
    foreach my $analysis_result_aref (@analysis_cluster_info) {
        
        my ($cluster_analysis_id, $cluster_analysis_name) = @$analysis_result_aref;
        
        my %expr_cluster_id_to_genes = &get_gene_clusters($dbproc, $cluster_analysis_id);
        
        foreach my $expr_cluster_id (keys %expr_cluster_id_to_genes) {
            
            print STDERR "\texamining $cluster_analysis_name cluster_id: $expr_cluster_id\n";
            

            my @genes = @{$expr_cluster_id_to_genes{$expr_cluster_id}};
            my $total_genes_in_cluster = scalar(@genes);

            my %genes_in_cluster = map { + $_ => 1 } @genes;
            
            ## get list of GO terms assigned
            my %terms;
            foreach my $gene (@genes) {
                if (my $go_href = $genes_to_go_href->{$gene}) {
                    
                    foreach my $go_id (keys %$go_href) {
                        $terms{$go_id} = 1;
                    }
                }
            }
            
            foreach my $term (keys %terms) {

                
                my $summary_struct = &do_enrichment_test($term, \@genes, $genes_to_go_href, $go_to_genes_href);
                my $Pval = $summary_struct->{Pval};
                my $enrichment = $summary_struct->{enrichment};
                my $descr = "NA";
                
                if (my $node = $go_dag->get_node($term)) {
                    $descr = join("\t", $node->{namespace}, $node->{name}, $node->{definition});
                }

                if ($Pval <= 0.05) {
                    print join("\t", $expr_cluster_id, $term, $Pval, $enrichment, $descr) . "\n";
                }
                
            }
            
            
        }
    }
}



####
sub get_GO_gene_data {
    my ($dbproc) = @_;

    
    my $go_dag = &GO_DAG::get_GO_DAG();
    

    my %go_to_genes;
    my %genes_to_go;

    print STDERR "\t-getting GO assignments from db.\n";
    
    my $query = "select T.gene_id, U.LinkId "
        . " from Transcript T, BlastDbase B, ORF O, UniprotIndex U "
        . " where T.transcript_id = O.transcript_id "
        . " and O.orf_id = B.TrinityID "
        . " and B.UniprotSearchString = U.Accession "
        . " and U.AttributeType = 'G' ";
    
    my @results = &do_sql_2D($dbproc, $query);
    
    foreach my $result (@results) {
        
        my ($gene_id, $go_id) = @$result;
        
        #print STDERR "$gene_id => $go_id\n";
        
        $go_to_genes{$go_id}->{$gene_id} = 1;
        $genes_to_go{$gene_id}->{$go_id} = 1;

    }

    my @go_ids = keys %go_to_genes;
    
    print STDERR "\t-trickling GO annots up the dag\n";

    foreach my $go_id (@go_ids) {

        eval {
            my @go_path_ids = $go_dag->get_all_ids_in_path($go_id);
            
            my @gene_ids = keys %{$go_to_genes{$go_id}};
            
            foreach my $gene_id (@gene_ids) {
                
                foreach my $go (@go_path_ids) {
                    
                    # print STDERR "Supp: $gene_id => $go\n";
                    
                    $go_to_genes{$go}->{$gene_id} = 1;
                    $genes_to_go{$gene_id}->{$go} = 1;
                    
                }
            }
        };
        if ($@) {
            #print STDERR $@;
            print STDERR "Warning, no record of $go_id\n";
        }
    }
    
    
    return(\%go_to_genes, \%genes_to_go, $go_dag);
}

