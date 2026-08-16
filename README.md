<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Archivist icon">
</p>

# Archivist

A native macOS archive manager. Browse, extract, compress, and test ZIP, RAR, 7Z, TAR, and related formats — without WinRAR source or branding.

RAR create and extract use official RARLAB command-line helpers, not a reimplemented compressor.

## Screenshots

Captured from the running app.

<p align="center">
  <img src="docs/screenshots/window.png" width="720" alt="Archivist main window">
  <br>
  <em>Main window — drop an archive to browse, or drop files to compress</em>
</p>

<p align="center">
  <img src="docs/screenshots/rar-window.png" width="720" alt="Archivist browsing a RAR archive">
  <br>
  <em>Opening a RAR archive — folders, sizes, and format details</em>
</p>

<p align="center">
  <img src="docs/screenshots/rar-finder.png" width="480" alt="RAR file in Finder with Archivist document icon">
  <br>
  <em>RAR files in Finder use Archivist’s document icon</em>
</p>

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

## Support

If Archivist is useful, you can [buy me a coffee](https://ko-fi.com/moomenaldahdouh).

<p>
  <a href="https://ko-fi.com/moomenaldahdouh">
    <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Buy me a coffee">
  </a>
</p>

## License

MIT for Archivist source. Third-party terms: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
