#!/bin/bash

set -ex


for file in data/*.gz
do
  if [ ! -e ${file%.gz} ]; then
      gunzip -c $file > ${file%.gz}
  fi
done

if [ ! -d DESeq2_trans ]; then
    tar xvf data/DESeq2_trans.tar
fi

if [ ! -d DESeq2_gene ]; then
    tar xvf data/DESeq2_gene.tar
fi


sqlite_db=myTrinotate.sqlite
trinotate_data_dir=`pwd`/TRINOTATE_DATA_DIR 


echo "############################"
echo "Trinotate create"
echo "############################"


../Trinotate --db $sqlite_db --create --trinotate_data_dir `pwd`/TRINOTATE_DATA_DIR


echo "###############################"
echo Trinotate Init
echo "###############################"

../Trinotate --db ${sqlite_db} --init --gene_trans_map data/Trinity.fasta.gene_to_trans_map --transcript_fasta data/Trinity.fasta --transdecoder_pep data/Trinity.fasta.transdecoder.pep



echo "##############################"
echo  Trinotate Run
echo "##############################"


../Trinotate --db ${sqlite_db} --run ALL --trinotate_data_dir `pwd`/TRINOTATE_DATA_DIR --transcript_fasta data/Trinity.fasta --transdecoder_pep data/Trinity.fasta.transdecoder.pep --use_diamond


echo "###########################"
echo Generating report table
echo "###########################"

../Trinotate --db ${sqlite_db} --report --incl_pep --incl_trans > Trinotate_report.tsv



echo "##########################"
echo done.  See annotation summary file:  Trinotate_report.tsv
echo "##########################"

