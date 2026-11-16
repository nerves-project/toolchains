# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0
#
# Top-level Makefile for Nerves Toolchains
# This Makefile instantiates all toolchain packages from the template

.PHONY: all refresh_version_info generate clean check test push-hex help

# List of all toolchains
TOOLCHAINS = \
	nerves_toolchain_aarch64_nerves_linux_gnu \
	nerves_toolchain_aarch64_nerves_linux_musl \
	nerves_toolchain_armv5_nerves_linux_musleabi \
	nerves_toolchain_armv6_nerves_linux_gnueabihf \
	nerves_toolchain_armv7_nerves_linux_gnueabihf \
	nerves_toolchain_armv7_nerves_linux_musleabihf \
	nerves_toolchain_i586_nerves_linux_gnu \
	nerves_toolchain_mipsel_nerves_linux_musl \
	nerves_toolchain_riscv64_nerves_linux_gnu \
	nerves_toolchain_riscv64_nerves_linux_musl \
	nerves_toolchain_x86_64_nerves_linux_gnu \
	nerves_toolchain_x86_64_nerves_linux_musl

all: refresh_version_info generate

refresh_version_info:
	@elixir toolchain_builder/update_versions.exs

# Generate all toolchain packages from template
generate:
	@elixir generate_toolchains.exs

build-armv7-gnu:
	./build_one.sh armv7-nerves-linux-gnueabihf--gcc15

build-riscv64-musl:
	./build_one.sh riscv64-nerves-linux-musl--gcc15

clean:
	@for tc in $(TOOLCHAINS); do \
		echo "Cleaning $$tc..."; \
		rm -rf $$tc/; \
	done

# Run package checks on all toolchain packages
check:
	@set -e; for tc in $(TOOLCHAINS) nerves_toolchain_gcc; do \
		echo "Checking $$tc..."; \
		(cd "$$tc"; mix deps.get; mix compile; mix docs; mix hex.build); \
	done

test:
	@elixir toolchain_builder/test/metadata_test.exs
	@cd nerves_toolchain_gcc && mix deps.get && mix test

# Push all toolchain packages to hex.pm
push-hex:
	@for tc in $(TOOLCHAINS); do \
		echo "Generating docs for $$tc..."; \
		cd $$tc && mix deps.get && mix docs && cd ..; \
	done; \
	for tc in $(TOOLCHAINS); do \
		echo "Pushing $$tc to hex..."; \
		cd $$tc && mix hex.publish --yes && cd ..; \
	done

push-hex-docs:
	@for tc in $(TOOLCHAINS); do \
		echo "Generating docs for $$tc..."; \
		cd $$tc && mix deps.get && mix docs && cd ..; \
	done; \
	for tc in $(TOOLCHAINS); do \
		echo "Publishing hex docs for $$tc..."; \
		cd $$tc && mix hex.publish docs --yes && cd ..; \
	done \

# Help target
help:
	@echo "Nerves Toolchains Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all (default)      - Generate all toolchain packages from template"
	@echo "  build-armv7-gnu    - Manually build an armv7 toolchain by directly calling its build.sh script"
	@echo "  build-riscv64-musl - Manually build a riscv64 toolchain one by directly calling its build.sh script"
	@echo "  generate           - Generate all toolchain packages from template"
	@echo "  clean              - Remove generated files from all toolchains (use with caution)"
	@echo "  check              - Run mix checks on all compatibility packages and the generic GCC package"
	@echo "  test               - Test archive packaging and generic GCC integration (no compiler build)"
	@echo "  push-hex           - Push all toolchain packages to hex.pm"
	@echo "  push-hex-docs      - Update toolchain docs on hex.pm"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Toolchains:"
	@for tc in $(TOOLCHAINS); do \
		echo "  - $$tc"; \
	done
