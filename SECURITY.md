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

7-Zip and UnRAR run as separate processes. RAR creation is not implemented.

## Sandbox

Hardened Runtime is enabled. App Sandbox is off so Finder Services, Dock drops, and arbitrary extract destinations work. A future Mac App Store variant would need security-scoped bookmarks.

## No network

Core archive operations are offline. There is no telemetry.
