#!/bin/bash

VERSION=`cat VERSION.txt`

docker push trinityrnaseq/trinotate:${VERSION} 
docker push trinityrnaseq/trinotate:latest
