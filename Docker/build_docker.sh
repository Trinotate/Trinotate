#!/bin/bash

set -e

VERSION=`cat VERSION.txt`

rm -f ./*simg


docker build -t trinityrnaseq/trinotate:$VERSION .
docker build -t trinityrnaseq/trinotate:latest .


