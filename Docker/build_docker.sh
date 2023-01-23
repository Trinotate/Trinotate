#!/bin/bash

set -e

VERSION=`cat VERSION.txt`


docker build -t trinityrnaseq/trinotate:$VERSION .


