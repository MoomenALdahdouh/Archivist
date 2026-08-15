# Release checklist

- [x] `swift build --product archivemgr`
- [x] `swift build --product ArchivistApp`
- [x] `ArchiveTestRunner` 39 passed / 0 failed
- [x] License audit files present
- [x] SUPPORTED_FORMATS.md documents RAR create via the official helper
- [x] `./Scripts/package-app.sh` produces Archivist.app
- [x] `./Scripts/release.sh` produces a DMG
- [ ] Optional helpers copied into Contents/Helpers
- [ ] Developer ID sign
- [ ] notarytool submit / staple
- [ ] spctl assess
- [ ] Double-click a .zip opens Archivist
- [ ] Extract Here service appears in Finder
- [ ] Universal binary verified (`lipo -archs`)
