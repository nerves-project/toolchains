#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION=${1:-}
ARTIFACT_DIR=${2:-"$BUILDER_DIR/o/artifacts"}

if [[ "$DESTINATION" != s3://* || "$DESTINATION" = s3:// ]]; then
    echo "publish.sh <s3://bucket/prefix> [artifact directory]" >&2
    exit 1
fi

location=${DESTINATION#s3://}
bucket=${location%%/*}
prefix=""
if [[ "$location" = */* ]]; then prefix=${location#*/}; fi
prefix=${prefix%/}
if [[ -n "$prefix" ]]; then prefix="$prefix/"; fi

shopt -s nullglob
archives=("$ARTIFACT_DIR"/*.tar.zst)
if [[ ${#archives[@]} = 0 ]]; then
    echo "No .tar.zst archives in $ARTIFACT_DIR" >&2
    exit 1
fi

for archive in "${archives[@]}"; do
    python3 "$BUILDER_DIR/scripts/artifact.py" verify "$archive"
done

upload()
{
    local file=$1 key=$2 content_type=$3 checksum existing
    checksum=$(python3 "$BUILDER_DIR/scripts/artifact.py" checksum "$file" | \
        python3 -c 'import base64, sys; print(base64.b64encode(bytes.fromhex(sys.stdin.read().split()[0])).decode())')

    if aws s3api put-object --bucket "$bucket" --key "$key" --body "$file" \
        --content-type "$content_type" --checksum-algorithm SHA256 \
        --checksum-sha256 "$checksum" --if-none-match '*'; then
        return
    fi

    existing=$(aws s3api head-object --bucket "$bucket" --key "$key" \
        --checksum-mode ENABLED --query ChecksumSHA256 --output text)
    if [[ "$existing" != "$checksum" ]]; then
        echo "Refusing to replace existing object with different content: $key" >&2
        return 1
    fi
    echo "Already published with matching checksum: $key"
}

for archive in "${archives[@]}"; do
    filename=$(basename "$archive")
    upload "$archive" "$prefix$filename" application/zstd
    # A checksum is the publication-complete marker; upload it last.
    upload "$archive.sha256" "$prefix$filename.sha256" text/plain
done
