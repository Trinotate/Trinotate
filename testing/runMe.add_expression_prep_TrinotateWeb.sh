#!/bin/bash -ex


if [ -z "$TRINOTATE_HOME" ]; then
    TRINOTATE_HOME=`pwd`/..
fi

sqlite_db=myTrinotate.sqlite
trinotate_data_dir=`pwd`/TRINOTATE_DATA_DIR 


#################################################################
## Load Expression info and DE analysis results for Trinotate-web
#################################################################


# import the expression data (counts, fpkms, and samples)

echo "###################################################"
echo Loading Component Expression Matrix and DE results
echo "###################################################"

# expression data load for genes
${TRINOTATE_HOME}/util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --gene_mode \
        --samples_file input_data/samples.txt \
        --count_matrix input_data/Trinity_genes.counts.matrix \
        --expr_matrix input_data/Trinity_genes.TMM.EXPR.matrix 

# DE results load for genes
${TRINOTATE_HOME}/util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --gene_mode \
        --samples_file input_data/samples.txt \
        --DE_dir DESeq2_gene


echo "##################################################"
echo Loading Transcript Expression Matrix and DE results
echo "##################################################"

# expression data load for transcripts
${TRINOTATE_HOME}/util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --transcript_mode \
        --samples_file input_data/samples.txt \
        --count_matrix input_data/Trinity_trans.counts.matrix \
        --expr_matrix input_data/Trinity_trans.TMM.EXPR.matrix

# DE results load for transcripts
${TRINOTATE_HOME}/util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --transcript_mode \
        --samples_file input_data/samples.txt \
        --DE_dir DESeq2_trans


echo "######################################################"
echo Loading transcription profile clusters for transcripts
echo "######################################################"


# import the transcription profile cluster stuff
${TRINOTATE_HOME}/util/transcript_expression/import_transcript_clusters.pl --group_name DE_all_vs_all --analysis_name diffExpr.P0.1_C1.matrix.RData.clusters_fixed_P_60 --sqlite ${sqlite_db} DESeq2_trans/diffExpr.P1e-3_C2.matrix.RData.clusters_fixed_P_60/*matrix

# Load annotations (for keyword searches)
${TRINOTATE_HOME}/util/annotation_importer/import_transcript_names.pl ${sqlite_db} Trinotate_report.tsv


echo "##########################"
echo done.  Use TrinotateWeb to explore expression data.
echo "##########################"

