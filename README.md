<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Archivist icon">
</p>

# Archivist

A native macOS archive manager. Browse, extract, compress, and test ZIP, RAR, 7Z, TAR, and related formats — without WinRAR source or branding.

RAR create and extract use official RARLAB command-line helpers, not a reimplemented compressor.

## Download

1. Get the latest **Archivist-1.0.0.dmg** from [Releases](https://github.com/MoomenALdahdouh/Archivist/releases).
2. Open the disk image and drag **Archivist** into **Applications**.
3. In Applications, **right-click Archivist → Open**. macOS may warn that the app is not notarized; choose **Open**.
4. Open Archivist once so Finder can find its actions.

This release is for **Apple Silicon** Macs (M1 and later) on **macOS 14** or newer.

### Finder

Right-click files in Finder and look under **Quick Actions** or **Services**:

- **Extract with Archivist**
- **Compress with Archivist** (ZIP)
- **Compress to RAR with Archivist**
- **Compress to 7Z with Archivist**

If an item is missing, open **System Settings → Keyboard → Keyboard Shortcuts → Services** and enable the Archivist actions under Files and Folders.

You can also double-click an archive, or drop files onto the Archivist window.

## Features

- Browse archive contents without extracting
- Extract all or selected entries, with overwrite policies and Zip Slip protection
- Create ZIP, RAR, 7Z, TAR, and compressed TAR/single-file formats
- Password-protected RAR, ZIP, and 7Z
- Job queue with byte progress, speed, and ETA
- `archivemgr` command-line tool (same engine as the app)
- Offline — no telemetry

## Command line

After installing the app, the CLI lives inside the bundle:

```bash
/Applications/Archivist.app/Contents/MacOS/archivemgr list archive.zip
/Applications/Archivist.app/Contents/MacOS/archivemgr extract archive.zip ./output
/Applications/Archivist.app/Contents/MacOS/archivemgr create ./folder archive.zip
/Applications/Archivist.app/Contents/MacOS/archivemgr test archive.rar
```

See [docs/CLI.md](docs/CLI.md) for options and exit codes.

## Build from source

You only need this if you are changing the code, or you have an Intel Mac.

```bash
git clone https://github.com/MoomenALdahdouh/Archivist.git
cd Archivist
./Scripts/install.sh
```

That installs Homebrew dependencies, downloads the official RARLAB helpers, builds the app, and copies it to `/Applications`.

Details: [BUILD.md](BUILD.md). Formats: [docs/SUPPORTED_FORMATS.md](docs/SUPPORTED_FORMATS.md). Problems: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## License

MIT for Archivist source. Third-party terms: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
