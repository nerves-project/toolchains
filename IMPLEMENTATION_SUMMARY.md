# Template Toolchain Package System - Implementation Summary

## Problem Statement

The toolchains packages had two major issues:

1. **Code Duplication**: All toolchain packages had nearly identical `mix.exs` files with only minor variations for `target_tuple`, module name, and version requirements. This made maintenance difficult and error-prone.

2. **Dependency Versioning Conflicts**: Keeping shared code in `nerves_toolchain_ctng` as a separate package caused dependency versioning conflicts when different toolchains required different versions.

## Solution

Implemented a template-based system that:

1. **Embeds Code**: Instead of depending on `nerves_toolchain_ctng` as an external package, the template system embeds the code directly into each toolchain package.

2. **Eliminates Duplication**: All toolchain packages are generated from a single template, ensuring consistency.

3. **Simplifies Maintenance**: Updates to shared code only require updating the template and regenerating packages.

## Components

### 1. Template Directory (`template/`)

Contains:
- `mix.exs.eex` - EEx template for mix.exs
- `README.md.eex` - EEx template for README.md
- `lib/nerves_toolchain_ctng.ex` - Embedded platform code
- `scripts/` - Build and packaging scripts
- `build.sh` - Main build script
- `patches/` - Crosstool-ng patches
- `defaults/` - Platform-specific configurations

### 2. Configuration and Generator (`generate_toolchains.exs`)

Elixir script that:
- Contains configuration for all 12 toolchains
- Uses EEx to process templates
- Generates `mix.exs` and `README.md` from templates
- Copies embedded code into each package
- Preserves toolchain-specific files (defconfig, VERSION, LICENSE)

### 3. Top-level Makefile

Provides convenient targets:
- `make generate` - Generate all toolchain packages
- `make help` - Show help
- `make clean-all` - Remove generated files

## Files Generated vs. Preserved

### Generated (overwritten on each generation):
- `mix.exs`
- `README.md`
- `lib/nerves_toolchain_ctng.ex`
- `scripts/` directory
- `build.sh`
- `patches/` directory
- `defaults/` directory

### Preserved (never overwritten):
- `defconfig` - Toolchain-specific configuration
- `VERSION` - Version number
- `LICENSE` - License file
- `mix.lock` - Dependency lock file

## Key Changes

1. **Removed Dependency**: All toolchain `mix.exs` files no longer have the `{:nerves_toolchain_ctng, path: "../nerves_toolchain_ctng", runtime: false}` dependency.

2. **Embedded Code**: Each toolchain package now contains its own copy of the platform code, scripts, patches, and build tools.

3. **Standardized Format**: The description field in `mix.exs` now uses a consistent format (hyphens instead of underscores for display).

## Benefits

1. **No Dependency Conflicts**: Each toolchain is self-contained
2. **Single Source of Truth**: Template directory contains all shared code
3. **Easy Updates**: Change template and regenerate to update all toolchains
4. **Consistency**: All toolchains use identical structure and code
5. **Reduced Duplication**: One template instead of 12+ nearly identical files

## Verification

- ✅ All 12 toolchains generated successfully
- ✅ Embedded code is identical across all toolchains (verified via MD5)
- ✅ Generated `mix.exs` files differ only in toolchain-specific values
- ✅ Regeneration works correctly after file removal
- ✅ No security vulnerabilities detected
- ✅ Code review passed with no comments

## Usage

### Generate all toolchains:
```bash
make generate
# or
elixir generate_toolchains.exs
```

### Add a new toolchain:
1. Add configuration to `generate_toolchains.exs`
2. Create directory `nerves_toolchain_<target_tuple>/`
3. Add `defconfig`, `VERSION`, and `LICENSE` files
4. Run `make generate`

### Update shared code:
1. Modify files in `template/`
2. Run `make generate`
3. Commit changes

## Migration Notes

For users of these toolchains:
- No changes required - the external interface remains the same
- Toolchains are still published to hex.pm the same way
- The only difference is internal structure (embedded code vs. dependency)

For maintainers:
- To update shared code, edit `template/` and regenerate
- To add a new toolchain, edit `toolchains.exs` and regenerate
- The `nerves_toolchain_ctng` directory can remain as a reference but is no longer used by individual toolchains
