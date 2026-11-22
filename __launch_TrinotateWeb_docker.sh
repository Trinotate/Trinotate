# inside the container lighttpd listens on all interfaces; the port is published on the host's localhost only
docker run --rm -it -v `pwd`:/data -e TRINOTATE_WEB_BIND=0.0.0.0 -p 127.0.0.1:8088:8088  trinityrnaseq/trinotate /usr/local/src/Trinotate/run_TrinotateWebserver.pl 8088
