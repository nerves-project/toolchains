# Top-level Makefile for Nerves Toolchains
# This Makefile instantiates all toolchain packages from the template

.PHONY: all generate clean push-hex help

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

all: generate

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

# Push all toolchain packages to hex.pm
push-hex:
	@for tc in $(TOOLCHAINS); do \
		echo "Pushing $$tc to hex..."; \
		cd $$tc && mix deps.get && mix hex.publish package --yes && cd ..; \
	done

# Help target
help:
	@echo "Nerves Toolchains Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all (default) - Generate all toolchain packages from template"
	@echo "  generate      - Generate all toolchain packages from template"
	@echo "  clean         - Remove generated files from all toolchains (use with caution)"
	@echo "  push-hex      - Push all toolchain packages to hex.pm"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Toolchains:"
	@for tc in $(TOOLCHAINS); do \
		echo "  - $$tc"; \
	done
