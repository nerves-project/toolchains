FROM hexpm/elixir:1.13.3-erlang-25.0.2-ubuntu-bionic-20210930
MAINTAINER Nerves Project
LABEL maintainer="Nerves Project developers <nerves@nerves-project.org>" \
      vendor="NervesProject" \
description="Container with everything needed to build Nerves toolchains"

# Setup environment
ENV DEBIAN_FRONTEND noninteractive
ENV LANG=C.UTF-8
ENV TERM=xterm
# The container has no package lists, so need to update first
RUN useradd -ms /bin/bash nerves
RUN set -xe \
  && apt-get update \
  && apt-get -y install \
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
	automake \
	libncurses5-dev \
	help2man \
	ca-certificates \
	unzip \
	lzip \
	python3 \
	rsync \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /root/.ssh \
  && ssh-keyscan -t rsa github.com > /root/.ssh/known_hosts \
  && chmod 700 /root/.ssh \
  && chmod 600 /root/.ssh/known_hosts

USER nerves
