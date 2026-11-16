# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

.PHONY: all build build-all test check format list

all: list

build:
	bash build.sh "$(TOOLCHAIN)"

build-all:
	bash build_all.sh

list:
	@for config in configs/*.defconfig; do basename "$$config" .defconfig; done

test:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s test -p '*_test.py'
	elixir test/metadata_test.exs

check: test
	mix format --check-formatted
	@for script in build.sh build_all.sh scripts/*.sh test/*.sh; do bash -n "$$script"; done

format:
	mix format
