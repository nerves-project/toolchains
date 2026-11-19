# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

.PHONY: all build build-all test check list ctng

CTNG_TAG = a4895d7fc49d5b423abc5f166895c80175019570
CTNG_PREFIX = $(CURDIR)/o/ct-ng
CTNG_MAKE = $(MAKE)
CTNG_ENV = SED=sed

ifeq ($(shell uname -s),Darwin)
BREW_PREFIX = $(shell brew --prefix)
BINUTILS_PREFIX = $(shell brew --prefix binutils)
NCURSES_PREFIX = $(shell brew --prefix ncurses)
CTNG_MAKE = $(BREW_PREFIX)/bin/gmake
CTNG_ENV = CC=gcc-16 CXX=g++-16 AR=gcc-ar-16 NM=gcc-nm-16 \
	RANLIB=gcc-ranlib-16 CPP=cpp-16 \
	OBJDUMP=$(BINUTILS_PREFIX)/bin/gobjdump \
	OBJCOPY=$(BINUTILS_PREFIX)/bin/gobjcopy \
	READELF=$(BINUTILS_PREFIX)/bin/greadelf \
	CFLAGS="-I$(BREW_PREFIX)/include -I$(NCURSES_PREFIX)/include" \
	LDFLAGS="-L$(BREW_PREFIX)/lib -lintl" \
	SED=$(BREW_PREFIX)/bin/gsed MAKE=$(CTNG_MAKE)
else ifeq ($(shell uname -s),FreeBSD)
CTNG_MAKE = /usr/local/bin/gmake
CTNG_ENV = SED=/usr/local/bin/gsed PATCH=/usr/local/bin/gpatch MAKE=$(CTNG_MAKE)
endif

all: list

ctng: o/ct-ng/.installed

o/ct-ng/.installed: export TMPDIR := $(CURDIR)/o/tmp
o/ct-ng/.installed: Makefile scripts/apply-patches.sh patches/crosstool-ng $(wildcard patches/crosstool-ng/*)
	rm -rf o/tmp/ct-ng-source o/ct-ng
	mkdir -p o/tmp
	git clone https://github.com/crosstool-ng/crosstool-ng.git o/tmp/ct-ng-source
	cd o/tmp/ct-ng-source && git checkout $(CTNG_TAG)
	bash scripts/apply-patches.sh o/tmp/ct-ng-source patches/crosstool-ng
	cd o/tmp/ct-ng-source && bash ./bootstrap
	cd o/tmp/ct-ng-source && $(CTNG_ENV) bash ./configure --prefix="$(CTNG_PREFIX)"
	cd o/tmp/ct-ng-source && $(CTNG_ENV) $(CTNG_MAKE)
	cd o/tmp/ct-ng-source && $(CTNG_ENV) $(CTNG_MAKE) install
	rm -rf o/tmp/ct-ng-source
	touch $@

build:
	bash build.sh "$(TOOLCHAIN)"

build-all:
	bash build_all.sh

list:
	@for config in configs/*.defconfig; do basename "$$config" .defconfig; done

test:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s test -p '*_test.py'

check: test
	@for script in build*.sh scripts/*.sh test/*.sh; do bash -n "$$script"; done
