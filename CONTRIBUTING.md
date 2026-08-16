# Contributing

Thanks for helping with Archivist.

1. Fork and clone the repo.
2. Install [Homebrew](https://brew.sh) and the Swift toolchain.
3. Run `./Scripts/install.sh` or `./Scripts/build.sh` then `./Scripts/test.sh`.
4. Keep format logic in `ArchiveCore` / `ArchiveBackends`, not in SwiftUI views.
5. Do not reimplement RAR compression or use UnRAR sources to create RAR archives. Create goes through RARLAB’s official `rar` helper.
6. Update [docs/SUPPORTED_FORMATS.md](docs/SUPPORTED_FORMATS.md) and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) when backends change.

Pull requests against `master` are welcome. Keep changes focused and include a short note on how you tested them.
