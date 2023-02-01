#!/bin/bash

set -ex

docker run --rm -it -v `pwd`:/data -e TRINOTATE_HOME=/usr/local/src/Trinotate trinityrnaseq/trinotate bash -c 'cd /data && ./runMe.sh && ./runMe.add_expression_prep_TrinotateWeb.sh'

