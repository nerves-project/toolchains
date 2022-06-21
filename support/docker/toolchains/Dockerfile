FROM ubuntu:18.04
MAINTAINER Nerves Project
LABEL maintainer="Nerves Project developers <nerves@nerves-project.org>" \
      vendor="NervesProject" \
description="Container with everything needed to build Nerves toolchains"

# Setup environment
ENV DEBIAN_FRONTEND noninteractive
ENV LANG=C.UTF-8
ENV TERM=xterm
ENV ERLANG_PKG='erlang-solutions_2.0_all.deb'
ENV ERLANG_URL="https://packages.erlang-solutions.com/${ERLANG_PKG}"
ENV ELIXIR_VERSION=1.13.0
ENV PATH="/usr/local/elixir/bin:${PATH}"
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
  && curl -o "/tmp/${ERLANG_PKG}" ${ERLANG_URL} \
  && dpkg -i "/tmp/${ERLANG_PKG}" \
  && apt-get update \
  && apt-get -y install \
    "esl-erlang" \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /root/.ssh \
  && ssh-keyscan -t rsa github.com > /root/.ssh/known_hosts \
  && chmod 700 /root/.ssh \
  && chmod 600 /root/.ssh/known_hosts \
	&& wget https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR_VERSION/Precompiled.zip \
  && unzip -d /usr/local/elixir Precompiled.zip

USER nerves
