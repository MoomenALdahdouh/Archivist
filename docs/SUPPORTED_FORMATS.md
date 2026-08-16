# Supported formats

Encrypted 7Z / RAR / WIM / MSI need the helpers produced by `Scripts/build-helpers.sh`. Release disk images already include them.

## Create

RAR (official RARLAB `rar` helper), ZIP, 7Z (unencrypted via libarchive; encrypted via 7-Zip helper), TAR, TAR.GZ, TAR.BZ2, TAR.XZ, TAR.ZST, TAR.LZ4, GZIP, BZIP2, XZ, LZMA, ZSTD, LZ4, CPIO, ISO, AR, CPGZ.

Finder’s **Compress with Archivist** action always writes ZIP. Use **Compress to RAR** or **Compress to 7Z**, or the in-app Compress sheet, for other formats.

## Extract

All creatable formats, plus RAR/RAR4/RAR5 (UnRAR helper, with libarchive/7-Zip fallback), ZIPX, CAB, XAR, JAR/WAR/EAR/APK/IPA/XPI/APPX, XIP, WIM/MSI (7-Zip helper), DMG (hdiutil).

## Password

RAR AES via the RAR helper. ZIP (ZipCrypto via libarchive; AES via 7-Zip helper). 7Z AES-256 via the 7-Zip helper.

## Split volumes

RAR volumes via the RAR helper. 7Z split volumes via the 7-Zip helper (`-v`).

## Modify

ZIP/7Z/TAR modification rebuilds to a temporary file and replaces atomically. The original archive is kept until the new file is written.

## Not supported

- Apple Archive (`.aar`)
- Brotli create on this libarchive build
- Pretending a helper-only format works when the helper is missing
- Reimplementing the proprietary RAR compressor (Archivist only invokes RARLAB’s official `rar` / `unrar`)

ZIP passwords through libarchive are ZipCrypto (legacy). AES ZIP needs the 7-Zip helper.
