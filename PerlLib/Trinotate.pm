package Trinotate;

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin");
use Sqlite_connect;
use Carp;

####
sub get_TmHMM_info {
    my ($dbproc, $prot_id) = @_;

    my $query = "select Score, PredHel, Topology from tmhmm where queryprotid = ? and PredHel != 'PredHel=0' ";
    my $result = &first_result_sql($dbproc, $query, $prot_id);
    
    if ($result) {
        
        my ($Score, $PredHel, $Topology) = @$result;
        my $struct = { Score => $Score,
                       PredHel => $PredHel,
                       Topology => $Topology,
        };
        return($struct);
    }
    else {
        return(undef);
    }
}


####
sub get_signalP_info {
    my ($dbproc, $prot_id) = @_;

    my $query = "select start, end, score, prediction from SignalP where query_prot_id = ?";
    my $result = &first_result_sql($dbproc, $query, $prot_id);
    if ($result) {
        
        my ($start, $end, $score, $prediction) = @$result;
        my $struct = { start => $start,
                       end => $end,
                       score => $score,
                       prediction => $prediction,
        };

        return($struct);
        
    }
    else {
        return(undef);
    }
}


###
sub get_pfam_info {
    my ($dbproc, $prot_id, $pfam_cutoff) = @_;

    if ($pfam_cutoff) {
        unless ($pfam_cutoff =~ /^(DNC|DGC|DTC|SNC|SGC|STC)$/) {
            confess "Error, need pfam_cutoff as param";
        }
    }
    
    
    my $query = "select pfam_id, HMMERDomain, HMMERTDomainDescription, QueryStartAlign, QueryEndAlign, ThisDomainEvalue, "
        . " p.Domain_NoiseCutoff, p.Domain_GatheringCutOff, p.Domain_TrustedCutOff, "
        . " p.Sequence_NoiseCutoff, p.Sequence_GatheringCutOff, p.Sequence_TrustedCutOff "
        . " from HMMERDbase h, PFAMreference p"
        . " where QueryProtID = ? "
        . " and p.pfam_accession = h.pfam_id ";
    
    if ($pfam_cutoff) {
        if ($pfam_cutoff eq "DNC") {
            $query .= " and h.FullDomainScore >= p.Domain_NoiseCutoff ";
        }
        elsif ($pfam_cutoff eq "DGC") {
            $query .= " and h.FullDomainScore >= p.Domain_GatheringCutOff ";
        }
        elsif ($pfam_cutoff eq "DTC") {
            $query .= " and h.FullDomainScore >= p.Domain_TrustedCutOff ";
        }
        elsif ($pfam_cutoff eq "SNC") {
            $query .= " and h.FullSeqScore >= p.Sequence_NoiseCutoff ";
        }
        elsif ($pfam_cutoff eq "SGC") {
            $query .= " and h.FullSeqScore >= p.Sequence_GatheringCutOff ";
        }
        elsif ($pfam_cutoff eq "STC") {
            $query .= " and h.FullSeqScore >= p.Sequence_TrustedCutOff ";
        }
    }
    
    $query .=  " order by QueryStartAlign ";
    
    my @results = &do_sql_2D($dbproc, $query, $prot_id);

    my @hits;
    
    foreach my $result (@results) {
        
        my ($pfam_id, $HMMERDomain, $HMMERTDomainDescription, $QueryStartAlign, $QueryEndAlign, $ThisDomainEvalue,
            $Domain_NoiseCutoff, $Domain_GatheringCutoff, $Domain_TrustedCutoff,
            $Sequence_NoiseCutoff, $Sequence_GatheringCutoff, $Sequence_TrustedCutoff
            ) = @$result;

        my $struct = { 'pfam_id' => $pfam_id,
                       'HMMERDomain' => $HMMERDomain,
                       'HMMERTDomainDescription' => $HMMERTDomainDescription,
                       'QueryStartAlign' => $QueryStartAlign,
                       'QueryEndAlign' => $QueryEndAlign,
                       'ThisDomainEvalue' => $ThisDomainEvalue,
        
                       'Domain_NoiseCutoff' => $Domain_NoiseCutoff,
                       'Domain_GatheringCutoff' => $Domain_GatheringCutoff,
                       'Domain_TrustedCutoff' => $Domain_TrustedCutoff,

                       'Sequence_NoiseCutoff' => $Sequence_NoiseCutoff,
                       'Sequence_GatheringCutoff' => $Sequence_GatheringCutoff,
                       'Sequence_TrustedCutoff' => $Sequence_TrustedCutoff,

        };
        
        push (@hits, $struct);
        
    }

    return(@hits);

}



####
sub get_custom_blast_database_names {
    my ($dbproc) = @_;

    my $query = "select distinct DatabaseSource from BlastDbase";
    my @results = &do_sql_2D($dbproc, $query);
    
    my @custom_dbs;
    
    foreach my $result (@results) {
        my ($db_name) = $result->[0];
        if ($db_name ne "Swissprot") { # Swissprot is the only 'reserved' one. All others are custom.
            push (@custom_dbs, $db_name);
        }
    }
    
    return(@custom_dbs);
}

####
sub count_protein_blastp_entries {
    my ($dbproc, $db_name) = @_;

    my $query = "select count(*) from ORF o, BlastDbase d where o.orf_id = d.TrinityID and d.DatabaseSource = ?";
    my $count = &very_first_result_sql($dbproc, $query, $db_name);

    return($count);    
}


####
sub count_transcript_blastx_entries {
    my ($dbproc, $db_name) = @_;

    my $query = "select count(*) from Transcript t, BlastDbase d where t.transcript_id = d.TrinityID and d.DatabaseSource = ?";
    my $count = &very_first_result_sql($dbproc, $query, $db_name);

    return($count);
}



####
sub get_blast_results {
    my ($dbproc, $Trinity_id, $Evalue_cutoff, $blast_method, $db) = @_;

    unless ($blast_method =~ /^(blastp|blastx)$/i) {
        confess "Error, must specify blast method: blastp or blastx";
    }

    my $query = "select FullAccession, UniprotSearchString, QueryStart, QueryEnd, HitStart, HitEnd, PercentIdentity, Evalue "
        . " from BlastDbase ";

    my $where = "";
    if ($blast_method =~ /blastp/) {
        $query .= ", ORF ";
        $where .= " and BlastDbase.TrinityID = ORF.orf_id ";
    }
    else {
        $query .= ", Transcript ";
        $where .= " and BlastDbase.TrinityID = Transcript.transcript_id ";
    }


    $query .= " where TrinityID = ? ";

    if (defined $Evalue_cutoff) {
        $query .= " and Evalue <= $Evalue_cutoff ";
    }
    
    if (defined $db) {
        $query .= " and DatabaseSource = \"$db\" ";
    }
    
    
    $query .= $where;
    
    $query .= " order by Evalue asc ";
    
    my @results = &do_sql_2D($dbproc, $query, $Trinity_id);
    
    
    my @top_hits;
    
    foreach my $result (@results) {
        
        my ($FullAccession, $UniprotSearchString, $QueryStart, $QueryEnd, $HitStart, $HitEnd, $PercentIdentity, $Evalue) = @$result;
        
        my $taxonomy_string = &__get_taxonomy_string($dbproc, $UniprotSearchString) || ".";
        $taxonomy_string =~ s/[\`\s]+/ /g; 
        $taxonomy_string =~ s/^\s+|\s+$//g;
        
        my $description_line = &__get_description_line($dbproc, $UniprotSearchString) || ".";
        
        $description_line =~ s/[\`\s]+/ /g; # using backtics as delimiters, and dont want tabs or newlines to disrupt formatting.
        $description_line =~ s/^\s+|\s+$//g;  
      

        my $struct = { FullAccession => $FullAccession,
                       UniprotSearchString => $UniprotSearchString,
                       QueryStart => $QueryStart,
                       QueryEnd => $QueryEnd,
                       HitStart => $HitStart,
                       HitEnd => $HitEnd,
                       PercentIdentity => $PercentIdentity,
                       Evalue => $Evalue,
        
                       TaxonomyString => $taxonomy_string,

                       DescriptionLine => $description_line,
                       
        };

        push (@top_hits, $struct);
        
    }
    
    return(@top_hits);

}



####
sub __get_taxonomy_string {
    my ($dbproc, $uniprot_acc) = @_;


    ## get the link ID
    my $query = "select u.LinkId from UniprotIndex u where u.AttributeType = 'T' and u.Accession = ?";
    my $link_id = &very_first_result_sql($dbproc, $query, $uniprot_acc);

    

    $query = "select t.TaxonomyValue from TaxonomyIndex t "
        . " where t.NCBITaxonomyAccession = ?";

    my $result = &very_first_result_sql($dbproc, $query, $link_id);
    
    return($result);
}

####
sub __get_description_line {
    my ($dbproc, $uniprot_acc) = @_;

    my $query = "select LinkId from UniprotIndex u where u.Accession = ? and u.AttributeType = 'D'";
    my $description = &very_first_result_sql($dbproc, $query, $uniprot_acc) || "";
    $description =~ s/^\s+|\s+$//g; # trim leading/trailing ws
    
    return($description);
}

####
sub get_eggnog_info_from_uniprot_acc {
    my ($dbproc, $uniprot_accession) = @_;

    my $query = "select eggNOGIndexTerm, eggNOGDescriptionValue "
        . " from eggNOGIndex e, UniprotIndex u "
        . " where u.Accession = ? "
        . " and u.AttributeType = 'E' "
        . " and u.LinkId = e.eggNOGIndexTerm ";

    my @results = &do_sql_2D($dbproc, $query, $uniprot_accession);
    
    my @eggnogs;
    foreach my $result (@results) {
        my ($eggnog_acc, $eggnog_descr) = @$result;
        
        if ($eggnog_descr) {
            $eggnog_descr =~ s/\s+/ /g;
        }
        
        my $struct = { eggNOGIndexTerm => $eggnog_acc,
                       eggNOGDescriptionValue => $eggnog_descr,
        };

        push (@eggnogs, $struct);
    }

    return(@eggnogs);
            
}


####
sub get_kegg_info_from_uniprot_acc {
    my ($dbproc, $uniprot_accession) = @_;

    my $query = "select u.LinkId "
        . " from UniprotIndex u "
        . " where u.Accession = ? "
        . " and u.AttributeType = 'K' ";
    
    my @results = &do_sql_2D($dbproc, $query, $uniprot_accession);
    
    my @kegg_info;
    foreach my $result (@results) {
        my ($kegg_acc) = @$result;
        push (@kegg_info, $kegg_acc);
    }
    
    return(@kegg_info);
    
}


####
sub get_gene_ontology_from_uniprot_acc {
    my ($dbproc, $uniprot_acc) = @_;

    my $query = "select g.id, g.namespace, g.name "
        . " from go g, UniprotIndex u "
        . " where u.Accession = ? "
        . " and u.AttributeType = 'G' "
        . " and u.LinkId = g.id ";

    #print $query . "  [$uniprot_acc]\n";
    
    my @results = &do_sql_2D($dbproc, $query, $uniprot_acc);
    
    #use Data::Dumper;
    #print Dumper(\@results);
    

    my @go;

    foreach my $result (@results) {
        my ($go_id, $go_namespace, $go_name) = @$result;
        
        my $struct = {'id' => $go_id,
                      'namespace' => $go_namespace,
                      'name' => $go_name,
        };
        
        push (@go, $struct);
    }

    return(@go);
    
}

####
sub get_gene_ontology_from_pfam_acc {
    my ($dbproc, $pfam_acc) = @_;

    $pfam_acc =~ s/\.\d+$//; # just want the core accession value

    my $query = "select g.id, g.namespace, g.name "
        . " from go g, pfam2go pf2g "
        . " where pf2g.pfam_acc = \"$pfam_acc\" "
        . " and pf2g.go_id = g.id ";

    
    #print STDERR "$query\n";
    
    my @results = &do_sql_2D($dbproc, $query);
    
    #use Data::Dumper;
    #print Dumper(\@results);
    

    my @go;

    foreach my $result (@results) {
        my ($go_id, $go_namespace, $go_name) = @$result;
        
        my $struct = {'id' => $go_id,
                      'namespace' => $go_namespace,
                      'name' => $go_name,
        };
        
        push (@go, $struct);
    }

    return(@go);
    
}



####
sub get_RNAMMER_info {
    my ($dbproc, $trans_id) = @_;
    
    my $query = "select Featurestart, Featureend, Featurescore, FeatureStrand, FeatureFrame, Featureprediction"
        . " from RNAMMERdata where TrinityQuerySequence = ? ";
    
    my @results = &do_sql_2D($dbproc, $query, $trans_id);
    
    my @structs;
    
    foreach my $result (@results) {
        my ($feature_start, $feature_end, $feature_score, $feature_strand, $feature_frame, $feature_prediction) = @$result;
        
        push (@structs, { feature_start => $feature_start,
                          feature_end => $feature_end,
                          feature_score => $feature_score,
                          feature_strand => $feature_strand,
                          feature_frame => $feature_frame,
                          feature_prediction => $feature_prediction,
                      });
    }
    
    return (@structs);
    
}


1; #EOM
