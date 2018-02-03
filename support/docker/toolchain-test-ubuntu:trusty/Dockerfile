FROM ubuntu:trusty
MAINTAINER Nerves Project
LABEL maintainer="Nerves Project developers <nerves@nerves-project.org>" \
      vendor="NervesProject" \
description="Test toolchains under ubuntu trusty"

# Setup environment
ENV DEBIAN_FRONTEND noninteractive
ENV LANG=C.UTF-8 
ENV TERM=xterm 

RUN set -xe \
  && apt-get update \
  && apt-get -y install \
		xz-utils \
    ca-certificates\
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /root/toolchain

COPY main.cpp /root
WORKDIR /root

