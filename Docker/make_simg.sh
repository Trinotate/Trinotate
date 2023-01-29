#!/bin/bash

VERSION=`cat VERSION.txt`

singularity build trinotate.v${VERSION}.simg docker://trinityrnaseq/trinotate:$VERSION

singularity exec -e trinotate.v${VERSION}.simg /usr/local/src/Trinotate/Trinotate

ln -sf  trinotate.v${VERSION}.simg  trinotate.simg

