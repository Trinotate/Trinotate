#!/bin/bash

if [ $* ]; then
    export MONGOOSE_CGI=LOCAL_JS
fi

mongoose -document_root `pwd`
