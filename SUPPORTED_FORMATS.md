# Supported formats

Capabilities below match this source tree. Encrypted 7Z / RAR / WIM / MSI require helpers built by `Scripts/build-helpers.sh`.

## Create

RAR (official RARLAB `rar` helper), ZIP, 7Z (unencrypted via libarchive; encrypted via 7-Zip helper), TAR, TAR.GZ, TAR.BZ2, TAR.XZ, TAR.ZST, TAR.LZ4, GZIP, BZIP2, XZ, LZMA, ZSTD, LZ4, CPIO, ISO, AR, CPGZ.

## Extract

All creatable formats, including RAR/RAR4/RAR5 (UnRAR helper, with libarchive/7-Zip fallback), ZIPX, CAB, XAR, JAR/WAR/EAR/APK/IPA/XPI/APPX, XIP, WIM/MSI (7-Zip helper), DMG (hdiutil).

## Password

RAR AES via the RAR helper. ZIP (ZipCrypto via libarchive; AES via 7-Zip helper). 7Z AES-256 via 7-Zip helper.

## Split volumes

RAR volumes via the RAR helper. 7Z split volumes via 7-Zip helper (`-v`).

## Modify

ZIP/7Z/TAR modification is implemented as rebuild to a temporary file and atomic replace. The original archive is kept until the new file is written.

## Not supported

Apple Archive (.aar) in this build. Pretending a helper-only format works when the helper is missing. Archivist does not reimplement the proprietary RAR compressor; it invokes RARLAB's official `rar`/`unrar` binaries.
