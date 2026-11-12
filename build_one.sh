#!/bin/sh

# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -e
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec bash "$ROOT/toolchain_builder/build.sh" "$@"

