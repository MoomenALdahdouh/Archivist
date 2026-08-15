import Foundation

public enum FormatCatalog {
    public static func capabilities(
        _ format: ArchiveFormat,
        sevenZipAvailable: Bool,
        unrarAvailable: Bool,
        rarCreateAvailable: Bool = false
    ) -> FormatCapabilities {
        switch format {
        case .zip:
            return FormatCapabilities(
                list: true, extract: true, create: true, test: true,
                password: true, encryptFilenames: false, split: sevenZipAvailable, modify: true,
                notes: "ZIP Crypto via libarchive is legacy/weak. AES ZIP uses the 7-Zip helper."
            )
        case .zipx:
            return FormatCapabilities(
                list: true, extract: true, create: true, test: true,
                notes: "ZIPX via libarchive (bzip2/zstd/lzma/xz methods where present)."
            )
        case .sevenZip:
            return FormatCapabilities(
                list: true, extract: true, create: true, test: true,
                password: sevenZipAvailable, encryptFilenames: sevenZipAvailable,
                split: sevenZipAvailable, modify: true,
                notes: sevenZipAvailable
                    ? "Unencrypted 7Z via libarchive; encrypted 7Z via 7-Zip helper."
                    : "Unencrypted 7Z via libarchive. Encrypted 7Z requires the 7-Zip helper."
            )
        case .rar, .rar5:
            return FormatCapabilities(
                list: true,
                extract: true,
                create: rarCreateAvailable,
                test: true,
                password: unrarAvailable || rarCreateAvailable,
                encryptFilenames: rarCreateAvailable,
                split: rarCreateAvailable || unrarAvailable,
                notes: rarCreateAvailable
                    ? "RAR create/extract via the official RARLAB helpers bundled with Archivist."
                    : "RAR extract works via UnRAR/libarchive. Creating RAR requires the official RARLAB `rar` helper."
            )
        case .tar, .pax:
            return FormatCapabilities(list: true, extract: true, create: true, test: true, modify: true)
        case .tarGz, .tarBz2, .tarXz, .tarZstd, .tarLz4, .cpgz:
            return FormatCapabilities(list: true, extract: true, create: true, test: true)
        case .gzip, .bzip2, .xz, .lzma, .lzip, .zstd, .lz4, .brotli, .compressZ:
            return FormatCapabilities(
                list: true, extract: true, create: format != .compressZ && format != .brotli ? true : (format == .brotli),
                test: true,
                notes: "Single-file compression."
            )
        case .cab, .iso, .cpio, .ar, .xar:
            return FormatCapabilities(list: true, extract: true, create: format == .iso || format == .cpio || format == .ar, test: true)
        case .wim, .msi:
            return FormatCapabilities(
                list: sevenZipAvailable, extract: sevenZipAvailable, create: false, test: sevenZipAvailable,
                notes: "Requires 7-Zip helper."
            )
        case .jar, .war, .ear, .apk, .ipa, .xpi, .appx:
            return FormatCapabilities(list: true, extract: true, create: false, test: true, notes: "ZIP container; extract only.")
        case .xip:
            return FormatCapabilities(list: true, extract: true, create: false, test: true, notes: "Signed Apple archive; extract as xar/zip derivative.")
        case .dmg:
            return FormatCapabilities(list: true, extract: true, create: false, test: false, notes: "DMG via hdiutil attach/copy. Not a general archive format.")
        case .appleArchive:
            return FormatCapabilities(list: false, extract: false, create: false, notes: "Not implemented in this build.")
        case .unknown:
            return .unsupported
        }
    }
}

public struct OpenIntent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case extractArchive(URL)
        case compressSources([URL])
        case mixed(archives: [URL], files: [URL])
    }

    public var kind: Kind

    public static func classify(_ urls: [URL]) -> OpenIntent {
        let fm = FileManager.default
        var archives: [URL] = []
        var files: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            _ = fm.fileExists(atPath: url.path, isDirectory: &isDir)
            let detection = FormatDetector.detect(url: url)
            if !isDir.boolValue, detection.format != .unknown, detection.confidence >= 0.5 {
                archives.append(url)
            } else {
                files.append(url)
            }
        }
        if !archives.isEmpty && files.isEmpty && archives.count == 1 {
            return OpenIntent(kind: .extractArchive(archives[0]))
        }
        if archives.isEmpty && !files.isEmpty {
            return OpenIntent(kind: .compressSources(files))
        }
        return OpenIntent(kind: .mixed(archives: archives, files: files))
    }
}
