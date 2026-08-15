# Known limitations

- **RAR create/extract** use the official RARLAB helpers (`ArchivistRar` / `ArchivistUnrar`) downloaded by `Scripts/build-helpers.sh`. Archivist does not reimplement RAR compression.
- **libarchive cannot decrypt 7Z or RAR.** Encrypted 7Z requires `7zz` / `Archivist7z`. Encrypted RAR requires UnRAR.
- **Single-file GZIP extract** uses `/usr/bin/gzip -dc` because libarchive's raw reader often reports a zero-size entry. Create still uses libarchive.
- **Brotli create** is not implemented in libarchive write filters on this build.
- **Apple Archive (.aar)** is not implemented.
- **Live notarization** needs a Developer ID Application certificate (this machine has Apple Development identities only).
- **Universal 2** is arm64 from SwiftPM on Apple Silicon. x86_64 requires a matching libarchive and `swift build --arch x86_64`.
- **Swift Testing / XCTest** are unavailable with Command Line Tools only. Tests run through `ArchiveTestRunner`.
- **XCUITest** Finder/UI automation is not run until full Xcode is installed.
- **10 GB+ fixtures** are generated on demand, not committed.
- **ZIP passwords** via libarchive are ZipCrypto (legacy/weak). AES ZIP needs the 7-Zip helper.
- **Overwrite policy `.ask`** is resolved in the UI before a job starts; the engine treats unresolved `.ask` as a conflict error rather than blocking a background thread.
- Homebrew libarchive is built for macOS 26; linking warns when targeting macOS 14. Runtime on macOS 26 is fine.
