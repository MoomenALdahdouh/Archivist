# Security

Archivist treats archives as untrusted input.

## Extraction

- Paths are normalized; `..`, absolute paths, `~`, drive letters, and null bytes are rejected.
- Extracted files must remain inside the chosen destination.
- Symlink targets that escape the destination are rejected.
- Device/special files are skipped.
- Configurable limits: max extracted bytes, file count, nesting depth, path length.
- Decompression-bomb warning when uncompressed/compressed exceeds the configured ratio above a size floor.
- Disk space is checked before extract when uncompressed size is known.

## Passwords

Passwords are never written to logs, history, or diagnostics. Keychain storage is opt-in.

## Helpers

7-Zip and RARLAB `rar`/`unrar` run as separate processes in `Contents/Helpers/`.

## Libraries

Release builds copy libarchive and its compression dylibs into `Contents/Frameworks/` and rewrite load paths to `@rpath`. The app does not need Homebrew at runtime.

Ad-hoc signed builds set `com.apple.security.cs.disable-library-validation` so those bundled libraries can load. Developer ID notarized builds should re-sign every dylib and helper with the same identity.

## Sandbox

App Sandbox is off so Finder Services, Dock drops, and arbitrary extract destinations work. A Mac App Store variant would need security-scoped bookmarks.

## No network

Core archive operations are offline. There is no telemetry. Helper downloads happen only when you build from source (`Scripts/build-helpers.sh`).
