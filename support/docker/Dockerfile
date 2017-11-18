FROM debian:9
MAINTAINER Nerves Project
LABEL maintainer="Nerves Project developers <nerves@nerves-project.org>" \
      vendor="NervesProject" \
description="Container with everything needed to build Nerves toolchains"

# Setup environment
ENV DEBIAN_FRONTEND noninteractive
RUN useradd -ms /bin/bash nerves

# Install dependencies.
RUN	apt-get update && \
	apt-get install -y git build-essential gperf bison flex texinfo wget gawk libtool automake libncurses5-dev help2man\
		ca-certificates unzip
RUN apt-get -q -y autoremove
RUN apt-get -q -y clean

USER nerves
