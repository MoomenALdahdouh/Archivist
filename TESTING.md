# Testing

Command Line Tools on this machine do not ship the Swift Testing or XCTest modules. Tests run via:

```bash
./Scripts/test.sh
```

which builds and executes `ArchiveTestRunner`.

Coverage:

- Magic-byte and extension format detection (including Arabic/Turkish names)
- Search wildcards and Unicode
- Zip Slip / symlink / bomb / path fuzz
- Progress and disk-space math
- Job completion
- CLI parse and exit codes
- Round-trip SHA-256 for ZIP, TAR, TAR.GZ, 7Z, GZIP
- Unicode filename round-trip

Generate extra fixtures:

```bash
./Scripts/generate-testdata.sh
```

UI tests that require XCUITest wait until full Xcode is installed.
