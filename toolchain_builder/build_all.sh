#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elixir "$ROOT/update_versions.exs"
for config in "$ROOT"/configs/*.defconfig; do
    bash "$ROOT/build.sh" "$(basename "$config" .defconfig)"
done
