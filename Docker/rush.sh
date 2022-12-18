










docker run --rm -it \
	-v /home/ramaiah/yeast_proteome/UP000002311_559292.fasta:/usr/local/src/UP000002311_559292.fasta \
	-v < some output directory >:/usr/local/src/output
	mbrown/test:devel



python -m tmbed embed -f /usr/local/src/UP000002311_559292.fasta -e sample.h5
