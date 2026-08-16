# Third-Party Licenses

This document reproduces license terms for third-party software that Archivist may link, invoke, or redistribute. Archivist's own source is MIT-licensed (see `LICENSE`). Archivist does not include WinRAR source, trademarks, icons, or proprietary UI assets.

## libarchive

Copyright (c) Tim Kientzle and contributors.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer in this position and unchanged.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.

Full upstream text: https://github.com/libarchive/libarchive/blob/master/COPYING

## 7-Zip (helper executable, optional)

7-Zip Copyright (C) 1999-2026 Igor Pavlov.

Most 7-Zip code is GNU LGPL 2.1 (or later). Some files use BSD-2-Clause or BSD-3-Clause. RAR decompression files are GNU LGPL **with the unRAR license restriction**.

Archivist ships 7-Zip as a **separate helper process** (`Archivist7z` / `7zz`) so the Archivist application is not a derivative work of 7-Zip under the LGPL. Users may replace the helper binary with a compatible LGPL build.

Binary redistributions must reproduce 7-Zip license information. See `Helpers/7zip/` after `Scripts/build-helpers.sh` runs.

Full upstream text: https://7-zip.org/license.txt

## UnRAR (helper executable, optional)

UnRAR is freeware owned by Alexander Roshal.

UnRAR source code may be used in any software to handle RAR archives without limitations free of charge, but cannot be used to develop a RAR (WinRAR) compatible archiver and to re-create the RAR compression algorithm, which is proprietary. Distribution of modified UnRAR source code in separate form or as a part of other software is permitted, provided that the full text of this paragraph is included in the license or documentation and in source comments of the resulting package.

The UnRAR utility may be freely distributed, including inside other software packages.

Archivist uses UnRAR **for extraction, listing, and testing**. Creating RAR archives is done with RARLAB's official `rar` command-line helper (`ArchivistRar`), not with UnRAR sources.

## RAR command-line helper (official RARLAB `rar`)

The `rar` binary is RARLAB's trial/commercial command-line archiver. Archivist invokes it as a separate process to create RAR archives. It is downloaded by `Scripts/build-helpers.sh` into `Helpers/build/` (gitignored) and copied into `Archivist.app/Contents/Helpers/`. See the license file shipped next to the helper (`RARLAB-license.txt`).

Release builds also copy libarchive plus liblzma, libzstd, liblz4, and libb2 into `Archivist.app/Contents/Frameworks/` so the app runs without Homebrew.

## zlib

Copyright (C) 1995-2024 Jean-loup Gailly and Mark Adler. zlib License.

## liblzma (XZ Utils)

Public domain (XZ Utils) / 0BSD for many files. See XZ Utils COPYING.

## zstd

BSD-3-Clause / GPLv2 dual license. Archivist uses the BSD-3-Clause terms when linking libzstd via libarchive.

## lz4

BSD-2-Clause.

## libb2

CC0 1.0 / public domain (BLAKE2 reference implementation).

## brotli

MIT License.

## Apple system frameworks

Foundation, SwiftUI, AppKit, Security, UniformTypeIdentifiers, Compression, OSLog, PDFKit, CryptoKit, and `hdiutil` are Apple system components. Their use is governed by Apple software terms, not redistributed as source.

## Swift toolchain

Swift is Apache 2.0 with Runtime Library Exception.
