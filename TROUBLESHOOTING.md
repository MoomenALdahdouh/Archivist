# Troubleshooting

**`archive.h` not found** — install Homebrew libarchive and use `./Scripts/build.sh` so include paths are set.

**Encrypted 7Z fails with “not currently supported”** — libarchive cannot decrypt 7Z. Install `7zz` (`brew install sevenzip`) and rerun `./Scripts/build-helpers.sh`.

**Encrypted RAR fails** — install UnRAR into `Helpers/build/ArchivistUnrar`. RAR creation is not available.

**App won’t launch after packaging** — ad-hoc sign with `codesign --force --sign - dist/Archivist.app`. Gatekeeper still blocks unsigned distribution until Developer ID notarization.

**Progress stuck indeterminate** — some formats do not expose uncompressed totals; that indicator is intentional, not a fake 99%.
