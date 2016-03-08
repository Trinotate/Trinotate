#!/bin/bash -e

SWISSPROT_SQLITE_DB_URL="https://data.broadinstitute.org/Trinity/Trinotate_v3_RESOURCES/Trinotate_v3.sqlite.gz";

for file in *.gz
do
  if [ ! -e ${file%.gz} ]; then
      gunzip -c $file > ${file%.gz}
  fi
done

if [ ! -d edgeR_trans ]; then
    tar -zxvf edgeR_trans.tgz
fi

if [ ! -d edgeR_components ]; then
    tar -zxvf edgeR_components.tgz
fi

BOILERPLATE="Trinotate.boilerplate.sqlite"

if [ -e $BOILERPLATE ]; then
    echo $BOILERPLATE
    rm $BOILERPLATE
fi

if [ ! -s $BOILERPLATE.gz ]; then
    echo pulling swissprot resource db from ftp site
    wget $SWISSPROT_SQLITE_DB_URL -O $BOILERPLATE.gz
fi

gunzip -c $BOILERPLATE.gz > $BOILERPLATE


sqlite_db="myTrinotate.sqlite"

if [ $* ]; then
    sqlite_db="/tmp/myTrinotate.sqlite"
fi

cp  $BOILERPLATE ${sqlite_db}

echo "###############################"
echo Loading protein set
echo "###############################"

../Trinotate ${sqlite_db} init --gene_trans_map Trinity.fasta.gene_trans_map --transcript_fasta Trinity.fasta --transdecoder_pep Trinity.fasta.transdecoder.pep



echo "##############################"
echo Loading blast results
echo "##############################"

../Trinotate ${sqlite_db} LOAD_swissprot_blastp swissprot.blastp.outfmt6
../Trinotate ${sqlite_db} LOAD_trembl_blastp uniref90.blastp.outfmt6


echo "#############################"
echo Loading PFAM results
echo "#############################"

../Trinotate ${sqlite_db} LOAD_pfam pfam.domtblout


echo "############################"
echo Loading TMHMM results
echo "############################"

../Trinotate ${sqlite_db} LOAD_tmhmm tmhmm.out

echo "###########################"
echo Loading SignalP results
echo "###########################"

../Trinotate ${sqlite_db} LOAD_signalp signalp.out

echo "###########################"
echo Loading transcript BLASTX results
echo "###########################"

../Trinotate ${sqlite_db} LOAD_swissprot_blastx swissprot.blastx.outfmt6
../Trinotate ${sqlite_db} LOAD_trembl_blastx uniref90.blastx.outfmt6


echo "###########################"
echo Loading RNAMMER results
echo "###########################"

../Trinotate ${sqlite_db} LOAD_rnammer rnammer.gff


#################################################################
## Load Expression info and DE analysis results for Trinotate-web
#################################################################


# import the expression data (counts, fpkms, and samples)

echo "###################################################"
echo Loading Component Expression Matrix and DE results
echo "###################################################"

# expression data load for genes
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --component_mode \
        --samples_file samples_n_reads_described.txt \
        --count_matrix Trinity_components.counts.matrix \
        --fpkm_matrix Trinity_components.counts.matrix.TMM_normalized.FPKM 

# DE results load for genes
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --component_mode \
        --samples_file samples_n_reads_described.txt \
        --DE_dir edgeR_components


echo "##################################################"
echo Loading Transcript Expression Matrix and DE results
echo "##################################################"

# expression data load for transcripts
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --transcript_mode \
        --samples_file samples_n_reads_described.txt \
        --count_matrix Trinity_trans.counts.matrix \
        --fpkm_matrix Trinity_trans.counts.matrix.TMM_normalized.FPKM

# DE results load for transcripts
../util/transcript_expression/import_expression_and_DE_results.pl --sqlite ${sqlite_db} --transcript_mode \
        --samples_file samples_n_reads_described.txt \
        --DE_dir edgeR_trans


echo "######################################################"
echo Loading transcription profile clusters for transcripts
echo "######################################################"


# import the transcription profile cluster stuff
../util/transcript_expression/import_transcript_clusters.pl --group_name DE_all_vs_all --analysis_name edgeR_trans/diffExpr.P0.001_C2.matrix.R.all.RData.clusters_fixed_P_20 --sqlite ${sqlite_db} edgeR_trans/diffExpr.P0.001_C2.matrix.R.all.RData.clusters_fixed_P_20/*matrix


echo "###########################"
echo Generating report table
echo "###########################"

../Trinotate ${sqlite_db} report > Trinotate_report.xls

echo "#########################################"
echo Extracting Gene Ontology Mappings Per Gene
echo "#########################################"

../util/extract_GO_assignments_from_Trinotate_xls.pl  --Trinotate_xls Trinotate_report.xls -G -I > Trinotate_report.xls.gene_ontology

# Load annotations
../util/annotation_importer/import_transcript_names.pl ${sqlite_db} Trinotate_report.xls


echo "##########################"
echo done.  See annotation summary file:  Trinotate_report.xls
echo "##########################"

