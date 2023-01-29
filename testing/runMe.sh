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

$TRINOTATE_HOME/Trinotate --db ${sqlite_db} --init --gene_trans_map data/Trinity.fasta.gene_to_trans_map --transcript_fasta data/Trinity.fasta --transdecoder_pep data/Trinity.fasta.transdecoder.pep



echo "##############################"
echo  Trinotate Run
echo "##############################"


$TRINOTATE_HOME/Trinotate --db ${sqlite_db} --run ALL --trinotate_data_dir `pwd`/TRINOTATE_DATA_DIR --transcript_fasta data/Trinity.fasta --transdecoder_pep data/Trinity.fasta.transdecoder.pep --use_diamond


echo "###########################"
echo Generating report table
echo "###########################"

$TRINOTATE_HOME/Trinotate --db ${sqlite_db} --report --incl_pep --incl_trans > Trinotate_report.tsv



echo "##########################"
echo done.  See annotation summary file:  Trinotate_report.tsv
echo "##########################"

