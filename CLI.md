# CLI

`archivemgr` shares ArchiveCore with the app.

```bash
archivemgr list archive.zip
archivemgr inspect archive.zip
archivemgr extract archive.zip ./output
archivemgr create ./folder archive.7z --format 7z
archivemgr test archive.rar
archivemgr formats
```

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
