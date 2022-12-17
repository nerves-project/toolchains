FROM hexpm/elixir:1.14.2-erlang-25.2-ubuntu-bionic-20210930
MAINTAINER Nerves Project
LABEL maintainer="Nerves Project developers <nerves@nerves-project.org>" \
      vendor="NervesProject" \
description="Container with everything needed to build Nerves toolchains"

# Setup environment
ENV DEBIAN_FRONTEND noninteractive
ENV LANG=C.UTF-8
ENV TERM=xterm

# Install packages
RUN apt-get update && \
    apt-get -y install \
	git \
	curl \
	build-essential \
        libtool \
	gperf \
	bison \
	flex \
	texinfo \
	wget \
	gawk \
	libtool-bin \
	libncurses5-dev \
	help2man \
	ca-certificates \
	unzip \
	lzip \
	python3 \
	rsync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/build

# Install autoconf and automake since Crosstool-NG requires newer versions
RUN cd /tmp/build && \
    wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz && \
    tar xvzf autoconf-2.71.tar.gz && \
    cd autoconf-2.71 && \
    ./configure --prefix=/usr && \
    make && \
    make install

RUN cd /tmp/build && \
    wget https://ftp.gnu.org/gnu/automake/automake-1.16.tar.gz && \
    tar xvzf automake-1.16.tar.gz && \
    cd automake-1.16 && \
    ./configure --prefix=/usr && \
    make && \
    make install

RUN rm -fr /tmp/build

# Set up ssh
RUN mkdir -p /root/.ssh && \
    ssh-keyscan -t rsa github.com > /root/.ssh/known_hosts && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/known_hosts

# Add the nerves user
RUN useradd -ms /bin/bash nerves
USER nerves
