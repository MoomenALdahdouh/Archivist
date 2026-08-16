#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libarchive/lib/pkgconfig:/usr/local/opt/libarchive/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
swift build --product ArchiveTestRunner
swift run ArchiveTestRunner
