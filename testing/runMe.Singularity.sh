#!/bin/bash

set -ex

singularity run -e ../Docker/trinotate.simg bash -c "export TRINOTATE_HOME=/usr/local/src/Trinotate && ./runMe.sh" 

