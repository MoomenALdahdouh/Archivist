# CLI

`archivemgr` shares ArchiveCore with the app. After a normal install:

```bash
/Applications/Archivist.app/Contents/MacOS/archivemgr list archive.zip
/Applications/Archivist.app/Contents/MacOS/archivemgr inspect archive.zip
/Applications/Archivist.app/Contents/MacOS/archivemgr extract archive.zip ./output
/Applications/Archivist.app/Contents/MacOS/archivemgr create ./folder archive.zip --format zip
/Applications/Archivist.app/Contents/MacOS/archivemgr create ./folder archive.rar --format rar
/Applications/Archivist.app/Contents/MacOS/archivemgr create ./folder archive.7z --format 7z
/Applications/Archivist.app/Contents/MacOS/archivemgr test archive.rar
/Applications/Archivist.app/Contents/MacOS/archivemgr formats
```

From a source checkout, `swift run archivemgr …` works after Homebrew libarchive is installed.

Options: `--password`/`-p`, `--json`, `--quiet`, `--overwrite`, `--include`, `--format`.

Passwords are never printed.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Archive corrupted |
| 4 | Wrong password |
| 5 | Missing volume |
| 6 | Unsupported format |
| 7 | Permission error |
| 8 | Disk space error |
| 9 | Cancelled |
