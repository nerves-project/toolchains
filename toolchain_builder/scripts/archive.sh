#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shopt -s nullglob
export LC_ALL=C

component()
{
    if [[ ! $1 =~ ^[A-Za-z0-9][A-Za-z0-9_.+-]*$ ]]; then
        echo "Invalid archive name component: $1" >&2
        exit 1
    fi
}

case "${1:-}:$#" in
    --check-config:3)
        mismatches=$(awk '
            {
                sub(/\r$/, "")
                if ($0 ~ /^CT_[A-Z0-9_]+=/) {
                    key = $0
                    sub(/=.*/, "", key)
                    value = substr($0, length(key) + 2)
                } else if ($0 ~ /^# CT_[A-Z0-9_]+ is not set$/) {
                    key = $2
                    value = "n"
                } else next
                if (FILENAME == ARGV[1]) expected[key] = value
                else actual[key] = value
            }
            END {
                for (key in expected)
                    if (!(key in actual) || actual[key] != expected[key])
                        printf "%s: requested %s, resolved %s\n", key, expected[key],
                            (key in actual ? actual[key] : "<missing>")
            }
        ' "$2" "$3" | sort)
        if [[ -n "$mismatches" ]]; then
            printf 'crosstool-NG changed explicit configuration:\n%s\n' "$mismatches" >&2
            exit 1
        fi
        ;;
    --find:5)
        directory=$2 config=$3 host=$4 release=$5
        if [[ $config = *--mingw_x86_64 ]]; then
            config=${config%--mingw_x86_64}
            if [[ $host != mingw_x86_64 ]]; then
                echo "Windows Canadian configs require mingw_x86_64 artifacts; use build_with_docker.sh" >&2
                exit 1
            fi
        fi
        target=${config%--gcc*}
        major=${config##*--gcc}
        component "$target"
        component "$host"
        component "$release"
        if [[ $target = "$config" || ! $major =~ ^[0-9]+$ ]]; then
            echo "Invalid toolchain config name: $config" >&2
            exit 1
        fi
        for archive in "$directory/$target--gcc-$major".*"--$release--$host.tar.xz"; do
            if [[ -f "$archive" && -f "$archive.sha256" ]]; then
                echo "$archive"
                break
            fi
        done
        ;;
    --name:3)
        install=$2 host=$3
        suffix=
        if [[ $host = mingw_x86_64 ]]; then suffix=.exe; fi
        compilers=("$install"/bin/*-gcc"$suffix")
        if [[ ${#compilers[@]} != 1 || ! -f ${compilers[0]} ]]; then
            echo "Expected exactly one installed *-gcc compiler" >&2
            exit 1
        fi
        target=${compilers[0]##*/}
        target=${target%.exe}
        target=${target%-gcc}
        versions=$(awk -F= '
            /^CT_[A-Z0-9_]+=/ {
                key = $1
                value = substr($0, length(key) + 2)
                sub(/\r$/, "", value)
                gsub(/^"|"$/, "", value)
                config[key] = value
            }
            END {
                if (config["CT_LIBC_MUSL"] == "y") libc = "musl"
                else if (config["CT_LIBC_GLIBC"] == "y") libc = "glibc"
                else {
                    print "Expected glibc or musl in ct-ng.config" > "/dev/stderr"
                    exit 1
                }
                printf "%s\t%s\t%s\t%s\n", config["CT_GCC_VERSION"],
                    config["CT_LINUX_VERSION"], libc, config["CT_" toupper(libc) "_VERSION"]
            }
        ' "$install/ct-ng.config")
        IFS=$'\t' read -r gcc linux libc libc_version <<< "$versions"
        for value in "$target" "$host" "$gcc" "$linux" "$libc_version"; do component "$value"; done
        release=$(cat "$ROOT/VERSION")
        if [[ ! $release =~ ^[0-9]{4}\.(0[1-9]|1[0-2])\.[1-9][0-9]*$ ]]; then
            echo "Release must be a calendar version YYYY.MM.N" >&2
            exit 1
        fi
        echo "$target--gcc-$gcc-$libc-$libc_version-linux-$linux--$release--$host.tar.xz"
        ;;
    *)
        echo "Usage: archive.sh --name <install> <host> | --find <directory> <config> <host> <release> | --check-config <base> <resolved>" >&2
        exit 1
        ;;
esac
