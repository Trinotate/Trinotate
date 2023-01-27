#!/bin/bash -ex


#################################################################
## Load Expression info and DE analysis results for Trinotate-web
#################################################################


# import the expression data (counts, fpkms, and samples)

echo "###################################################"
echo Loading Component Expression Matrix and DE results
echo "###################################################"

# expression data load for genes
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --gene_mode \
        --samples_file data/samples.txt \
        --count_matrix data/Trinity_genes.counts.matrix \
        --fpkm_matrix data/Trinity_genes.TMM.EXPR.matrix 

# DE results load for genes
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --gene_mode \
        --samples_file data/samples.txt \
        --DE_dir DESeq2_gene


echo "##################################################"
echo Loading Transcript Expression Matrix and DE results
echo "##################################################"

# expression data load for transcripts
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --transcript_mode \
        --samples_file data/samples.txt \
        --count_matrix data/Trinity_trans.counts.matrix \
        --fpkm_matrix data/Trinity_trans.TMM.EXPR.matrix

# DE results load for transcripts
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --transcript_mode \
        --samples_file data/samples.txt \
        --DE_dir DESeq2_trans


echo "######################################################"
echo Loading transcription profile clusters for transcripts
echo "######################################################"


# import the transcription profile cluster stuff
../util/transcript_expression/import_transcript_clusters.pl --group_name DE_all_vs_all --analysis_name diffExpr.P0.1_C1.matrix.RData.clusters_fixed_P_60 --sqlite ${sqlite_db} DESeq2_trans/diffExpr.P1e-3_C2.matrix.RData.clusters_fixed_P_60/*matrix





echo "#########################################"
echo Extracting Gene Ontology Mappings Per Gene
echo "#########################################"

../util/extract_GO_assignments_from_Trinotate_xls.pl  --Trinotate_xls Trinotate_report.xls -G -I > Trinotate_report.xls.gene_ontology

# Load annotations
../util/annotation_importer/import_transcript_names.pl ${sqlite_db} Trinotate_report.xls



# Generate trinotate report summary statistics
../util/report_summary/trinotate_report_summary.pl Trinotate_report.xls Trinotate_report_stats


echo "##########################"
echo done.  See annotation summary file:  Trinotate_report.xls
echo "##########################"

