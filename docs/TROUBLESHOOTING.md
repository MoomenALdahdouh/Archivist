# Troubleshooting

**macOS says the app can’t be opened** — the public disk image is ad-hoc signed, not notarized. Right-click Archivist in Applications, choose **Open**, then confirm. You only need to do this once.

**“Archivist is damaged” or it quits immediately** — download the DMG again from [Releases](https://github.com/MoomenALdahdouh/Archivist/releases). The app must include `Contents/Frameworks/libarchive.13.dylib`. It should not require Homebrew to run.

**Finder Extract / Compress actions are missing** — open Archivist once. Then System Settings → Keyboard → Keyboard Shortcuts → Services, and enable the Archivist items under Files and Folders. They appear as Quick Actions or Services, not as a new top-level Finder menu.

**`archive.h` not found when building from source** — install Homebrew libarchive and use `./Scripts/build.sh` so include paths are set.

**Encrypted 7Z fails with “not currently supported”** — libarchive cannot decrypt 7Z. The release app bundles `Archivist7z`. From source, `brew install sevenzip` and rerun `./Scripts/build-helpers.sh`.

**Encrypted RAR fails, or RAR create fails** — the release app bundles `ArchivistUnrar` and `ArchivistRar`. From source, run `Scripts/build-helpers.sh` so those helpers exist under `Contents/Helpers`.

**Progress looks stuck** — some formats do not expose uncompressed totals. An indeterminate spinner is intentional, not a fake 99%.

**Intel Mac** — the published DMG is Apple Silicon. Build from source with `./Scripts/install.sh`.

**Single-file GZIP extract** — Archivist uses `/usr/bin/gzip -dc` because libarchive’s raw reader often reports a zero-size entry. Create still uses libarchive.

**Overwrite “Ask”** — the UI resolves this before a job starts. The engine treats an unresolved ask as a conflict rather than blocking a background thread.
