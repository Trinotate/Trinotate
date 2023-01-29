FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

#~~~~~~~~~~~~~~
# Install Preliminaries
#~~~~


RUN apt-get -qq update && apt-get -qq -y install \
    automake \
    build-essential \
    bzip2 \
    cmake \
    curl \
    default-jre \
    fort77 \
    ftp \
    g++ \
    gcc \
    gfortran \
    git \
    libblas-dev \
    libbz2-dev \
    libcairo2-dev \
    libcurl4-openssl-dev \
    libdb-dev \
    libghc-zlib-dev \
    libjpeg-dev \
    liblzma-dev \
    libncurses-dev \
    libncurses5-dev \
    libpcre3-dev \
    libpng-dev \
    libreadline-dev \
    libreadline-dev \
    libssl-dev \
    libtbb-dev \
    libx11-dev \
    libxml2-dev \
    libxt-dev \
    libzmq3-dev \
    make \
    nano \
    perl \
    pkg-config \
    python3 \
    python3-dev \
    python3-distutils \
    python3-pip \
    python3-setuptools \
    rsync \
    texlive-latex-base \
    tzdata \
    unzip \
    wget \
    x11-common \
    zlib1g-dev



## Perl stuff
RUN curl -L https://cpanmin.us | perl - App::cpanminus
RUN cpanm install DB_File
RUN cpanm install URI::Escape

#~~~~~~~~~~~
# Environmental Variables 
#~~~~~~~~~~~
ENV SRC /usr/local/src
ENV BIN /usr/local/bin


#~~~~~~~~~~~~~~~~~
# DeepTmHMM
#~~~~~~~~~~~~~~~~~
RUN pip install pybiolib




#~~~~~~~~~~~~~~
# TMbed
#~~~~~~~~~~~~~~
# Need for ssl reasons 
#RUN git config --global http.sslverify false
# install 
#RUN pip install git+https://github.com/BernhoferM/TMbed.git




#~~~~~~~~~~~~~~~
# pybiolib
#~~~~~~~~~~~~~~~
RUN pip install pybiolib

#~~~~~~~~~~~~~~~
# signalp-6-package   (cannot distribute due to licensing restrictions)
#~~~~~~~~~~~~~~~
# add the file to the docker image
#COPY signalp-6.0g.fast.tar /usr/local/src 
# install it 
#RUN tar -xvf /usr/local/src/signalp-6.0g.fast.tar && \
#    cd signalp6_fast && \
#    pip install signalp-6-package/ && \
#    SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))" ) && \
#    cp -r signalp-6-package/models/* $SIGNALP_DIR/model_weights/ 
# Remove the file, takes up memory 
# RUN rm /usr/local/src/signalp-6.0g.fast.tar



# blast
WORKDIR $SRC
ENV BLASTPLUS_VERSION 2.12.0
RUN wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${BLASTPLUS_VERSION}/ncbi-blast-${BLASTPLUS_VERSION}+-x64-linux.tar.gz && \
    tar xvf ncbi-blast-${BLASTPLUS_VERSION}+-x64-linux.tar.gz && \
    cp ncbi-blast-${BLASTPLUS_VERSION}+/bin/* $BIN && \
    rm -r ncbi-blast-${BLASTPLUS_VERSION}+



#~~~~~~~~~~~~~~
# diamondblast
#~~~~~~~~~~~~~~

WORKDIR $SRC
RUN wget https://github.com/bbuchfink/diamond/releases/download/v2.0.15/diamond-linux64.tar.gz && \
    tar xvf diamond-linux64.tar.gz && \
    mv diamond $BIN/


#~~~~~~~~~~~~~~~~
# TransDecoder
#~~~~~~~~~~~~~~~~

WORKDIR $SRC
RUN wget https://github.com/TransDecoder/TransDecoder/archive/refs/tags/TransDecoder-v5.5.0.tar.gz && \
   tar xvf TransDecoder-v5.5.0.tar.gz && \
   cp -r TransDecoder-TransDecoder-v5.5.0/* $BIN/


#~~~~~~~~~~~~~~~~
# Infernal
#~~~~~~~~~~~~~~~~~

WORKDIR $SRC
RUN wget eddylab.org/infernal/infernal-1.1.2.tar.gz && \
     tar xvf infernal-1.1.2.tar.gz && \
     cd infernal-1.1.2 && \
     ./configure && \
     make && make install


#~~~~~~~~~~~~~~~~~~~~
# Hmmer
#~~~~~~~~~~~~~~~~~~~

WORKDIR $SRC
RUN wget http://eddylab.org/software/hmmer/hmmer.tar.gz && \
    tar xvf hmmer.tar.gz && \
    cd hmmer-3.3.2 && \
    ./configure && \
    make && make install


#~~~~~~~~~~~~~~~~~~~~~
# Eggnog Mapper
#~~~~~~~~~~~~~~~~~~~~
WORKDIR $SRC
RUN wget https://github.com/eggnogdb/eggnog-mapper/archive/refs/tags/2.1.9.tar.gz && \
    tar xvf 2.1.9.tar.gz && \
    cp -r eggnog-mapper-2.1.9 $BIN/



#~~~~~~~~~~~~~~~~~~
# Trinotate
#~~~~~~~~~~~~~~~~~~

RUN apt-get update && apt-get install -y lighttpd

WORKDIR $SRC
ENV TRINOTATE_CO=21927721a5c1a38fe4af57238fc1198c9a50d616

RUN git clone https://github.com/Trinotate/Trinotate.git && \
    cd Trinotate && \
    git checkout $TRINOTATE_CO

RUN apt-get update && apt-get install -y sqlite3


RUN cpanm install DB_File \
                  URI::Escape \
                  DBI \
                  DBD::SQLite


ENV PATH=${PATH}:$BIN/eggnog-mapper-2.1.9


RUN pip install -r $BIN/eggnog-mapper-2.1.9/requirements.txt

#################
# clean up image:
#RUN apt-get -qq -y remove automake build-essential cmake curl git gcc g++ wget && \
#    apt-get -qq -y autoremove && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/* /var/log/dpkg.log





