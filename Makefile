# Top-level Makefile for Nerves Toolchains
# This Makefile instantiates all toolchain packages from the template

.PHONY: all refresh_version_info generate clean check push-hex help

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
	@elixir update_toolchain_versions.exs

# Generate all toolchain packages from template
generate:
	@elixir generate_toolchains.exs

build-one:
	nerves_toolchain_armv7_nerves_linux_gnueabihf/build.sh nerves_toolchain_armv7_nerves_linux_gnueabihf/defconfig $(PWD)/o/nerves_toolchain_armv7_nerves_linux_gnueabihf

clean:
	@for tc in $(TOOLCHAINS); do \
		echo "Cleaning $$tc..."; \
		rm -rf $$tc/; \
	done

# Run package checks on all toolchain packages
check:
	@for tc in $(TOOLCHAINS); do \
		echo "Checking $$tc..."; \
		cd $$tc && mix deps.get && mix compile && mix docs && mix hex.build && cd ..; \
	done

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
	@echo "  all (default) - Generate all toolchain packages from template"
	@echo "  generate      - Generate all toolchain packages from template"
	@echo "  clean         - Remove generated files from all toolchains (use with caution)"
	@echo "  check         - Run mix checks on all generated toolchain packages"
	@echo "  push-hex      - Push all toolchain packages to hex.pm"
	@echo "  push-hex-docs - Update toolchain docs on hex.pm"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Toolchains:"
	@for tc in $(TOOLCHAINS); do \
		echo "  - $$tc"; \
	done
