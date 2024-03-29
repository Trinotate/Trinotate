#!/bin/bash

set -ex

if [ -z "$TRINOTATE_HOME" ]; then
    TRINOTATE_HOME=`pwd`/..
fi

for file in input_data/*.gz
do
  if [ ! -e ${file%.gz} ]; then
      gunzip -c $file > ${file%.gz}
  fi
done

if [ ! -d DESeq2_trans ]; then
    tar xvf input_data/DESeq2_trans.tar
fi

if [ ! -d DESeq2_gene ]; then
    tar xvf input_data/DESeq2_gene.tar
fi


sqlite_db=myTrinotate.sqlite
trinotate_data_dir=`pwd`/TRINOTATE_DATA_DIR 


echo "############################"
echo "Trinotate create"
echo "############################"


$TRINOTATE_HOME/Trinotate --db $sqlite_db --create --trinotate_data_dir `pwd`/TRINOTATE_DATA_DIR


echo "###############################"
echo Trinotate Init
echo "###############################"

$TRINOTATE_HOME/Trinotate --db ${sqlite_db} --init --gene_trans_map input_data/Trinity.fasta.gene_to_trans_map --transcript_fasta input_data/Trinity.fasta --transdecoder_pep input_data/Trinity.fasta.transdecoder.pep



echo "##############################"
echo  Trinotate Run
echo "##############################"


$TRINOTATE_HOME/Trinotate --db ${sqlite_db} --run ALL --trinotate_data_dir `pwd`/TRINOTATE_DATA_DIR --transcript_fasta input_data/Trinity.fasta --transdecoder_pep input_data/Trinity.fasta.transdecoder.pep --use_diamond


echo "###########################"
echo Generating report table
echo "###########################"

$TRINOTATE_HOME/Trinotate --db ${sqlite_db} --report --incl_pep --incl_trans > Trinotate_report.tsv

##################
## Misc value adds
##################

# Extract GO terms
${TRINOTATE_HOME}/util/extract_GO_assignments_from_Trinotate_xls.pl  --Trinotate_xls Trinotate_report.tsv -G -I > Trinotate_report.xls.gene_ontology

# Generate trinotate report summary statistics
${TRINOTATE_HOME}/util/report_summary/trinotate_report_summary.pl Trinotate_report.tsv Trinotate_report_stats

echo "##########################"
echo done.  See annotation summary file:  Trinotate_report.tsv
echo "##########################"

