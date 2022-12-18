FROM --platform=linux/amd64 ubuntu:23.04
MAINTAINER mbrown@broadinstitute.org
ENV DEBIAN_FRONTEND=noninteractive

#~~~~~~~~~~~~~~
# Install Preliminaries
#~~~~~~~~~~~~~~

RUN apt-get -qq update && apt-get -qq -y install --no-install-recommends \
    automake \
    build-essential \
    curl \
    g++ \
    gcc \
    git \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    make \
    wget \
    zlib1g-dev 



#~~~~~~~~~~~
# Environmental Variables 
#~~~~~~~~~~~
ENV SRC /usr/local/src
ENV BIN /usr/local/bin

#~~~~~~~~~~~~~~~~~~~~~~~~
# Python from source
#~~~~~~~~~~~~~~~~~~~~~~~~
# adjust working directory 
WORKDIR $SRC

# Download 
RUN wget --no-check-certificate https://www.python.org/ftp/python/3.9.15/Python-3.9.15.tgz
RUN tar -xf Python-3.9.15.tgz

# install
RUN cd Python-3.9.15 && \
    ./configure --enable-optimizations && \
    make && \
    make altinstall
RUN python3.9 -m pip install --upgrade pip

# Set link so you can type python instead of python3.9, also make default python
RUN ln -sf /usr/local/bin/python3.9 /usr/bin/python




WORKDIR $SRC

#~~~~~~~~~~~~~~
# TMbed
#~~~~~~~~~~~~~~
# Need for ssl reasons 
RUN git config --global http.sslverify false
# install 
RUN pip install git+https://github.com/BernhoferM/TMbed.git

#~~~~~~~~~~~~~~~
# pybiolib
#~~~~~~~~~~~~~~~
RUN pip install pybiolib

#~~~~~~~~~~~~~~~
# signalp-6-package
#~~~~~~~~~~~~~~~
# add the file to the docker image
COPY signalp-6.0g.fast.tar /usr/local/src 

# install it 
RUN tar -xvf /usr/local/src/signalp-6.0g.fast.tar && \
    cd signalp6_fast && \
    pip install signalp-6-package/ && \
    SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))" ) && \
    cp -r signalp-6-package/models/* $SIGNALP_DIR/model_weights/ 

# Remove the file, takes up memory 
RUN rm /usr/local/src/signalp-6.0g.fast.tar
RUN rm /usr/local/src/Python-3.9.15.tgz



RUN apt-get -qq -y remove automake build-essential cmake curl git gcc g++ wget && \
    apt-get -qq -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/log/dpkg.log





