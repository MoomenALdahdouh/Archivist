# Dependency License Audit

Audit date: 2026-08-15
Product: Archivist (native macOS archive manager)

This audit was performed **before** vendoring helper sources. Do not add a backend without updating this file.

## Summary

| Component | Use | License | Linking | Redistribution | Notes |
| --- | --- | --- | --- | --- | --- |
| Archivist source | App, CLI, engine | MIT | n/a | Yes | Original work |
| libarchive | Primary archive I/O | BSD-2-Clause (plus some file-level notices) | Static or dynamic allowed | Yes, with copyright notice | Preferred backend |
| 7-Zip | Encrypted 7Z, WIM, MSI, split volumes | LGPL-2.1 + mixed BSD + unRAR restriction on RAR decoder files | **Separate helper process only** | Yes, with LGPL notices and source/object offer for the helper | Do not statically link into the app |
| UnRAR | RAR4/RAR5 extract/list/test | UnRAR freeware | **Separate helper process only** | Yes, with required paragraph | Extract-only |
| RAR (RARLAB CLI) | RAR create | RARLAB trial/commercial | **Separate helper process only** | Do not reimplement compression; invoke official `rar` | Downloaded by `build-helpers.sh`, not compiled from UnRAR sources |
| zlib / liblzma / zstd / lz4 / brotli | Filters via libarchive or system | zlib / public domain / BSD / MIT | Via libarchive or system | Yes | |
| hdiutil | DMG workflows | Apple system tool | Process invoke | Do not redistribute the tool | Adapter only |
| Apple Compression / Apple Archive | Optional native compression | Apple SDK | Framework link | Do not redistribute SDK | |

## RAR

Creating RAR archives requires RARLAB's official compressor. Archivist **does not reimplement** the RAR compression algorithm, will not reverse-engineer WinRAR, and will not use UnRAR sources to build a compressor. Create is performed by invoking the official `rar` helper (`ArchivistRar`) as a separate process.

libarchive includes an independent RAR reader with limitations (including **no encrypted RAR/7Z decryption**). Encrypted RAR extraction is delegated to the UnRAR helper when present.

## 7-Zip LGPL compliance plan

1. Build `7zz` (or `Archivist7z`) as its own executable.
2. Place it in `Archivist.app/Contents/Helpers/`.
3. Ship `THIRD_PARTY_LICENSES.md` and the 7-Zip license next to the helper.
4. Allow users to replace the helper binary.
5. Offer corresponding 7-Zip source used for the helper build in `Helpers/7zip/` or a clearly documented URL/tag.

## libarchive encrypted formats

libarchive can detect encryption and can decrypt **ZIP** with a passphrase. It **cannot** decrypt 7Z or RAR (`Reading encrypted data is not currently supported`). Those paths must go through helpers or be reported as unsupported — never pretended.

## Sandbox / Hardened Runtime

Archivist is intended to ship with **Hardened Runtime** and **without App Sandbox**. An archive utility that extracts to arbitrary folders, accepts Dock drops, and shares a CLI cannot honestly operate fully sandboxed without constant user-hostile permission prompts. A future App Store variant would need security-scoped bookmarks and reduced Finder integration.

## Patents

No MPEG, H.264, or other media codecs are bundled. Compression algorithms used (Deflate, LZMA, Zstandard, Brotli, bzip2) are treated as implementable via the licensed libraries above. RAR compression is provided only by invoking RARLAB's official `rar` binary.

## Actions required when adding a dependency

1. Identify license and whether static linking is allowed.
2. Record it in this table.
3. Reproduce the license in `THIRD_PARTY_LICENSES.md`.
4. If copyleft (LGPL/GPL), isolate as a replaceable helper or do not include.
5. Rebuild and re-run this audit.
