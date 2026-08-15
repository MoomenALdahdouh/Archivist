import Foundation

/// Archive formats Archivist can detect. Capabilities are declared separately and must not be overstated.
public enum ArchiveFormat: String, Sendable, CaseIterable, Codable, Identifiable, Hashable {
    case zip
    case zipx
    case sevenZip
    case rar
    case rar5
    case tar
    case tarGz
    case tarBz2
    case tarXz
    case tarZstd
    case tarLz4
    case gzip
    case bzip2
    case xz
    case lzma
    case lzip
    case compressZ
    case zstd
    case lz4
    case brotli
    case cab
    case wim
    case iso
    case cpio
    case pax
    case ar
    case xar
    case dmg
    case appleArchive
    case jar
    case war
    case ear
    case apk
    case ipa
    case xpi
    case appx
    case msi
    case xip
    case cpgz
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zip: "ZIP"
        case .zipx: "ZIPX"
        case .sevenZip: "7Z"
        case .rar: "RAR4"
        case .rar5: "RAR"
        case .tar: "TAR"
        case .tarGz: "TAR.GZ"
        case .tarBz2: "TAR.BZ2"
        case .tarXz: "TAR.XZ"
        case .tarZstd: "TAR.ZST"
        case .tarLz4: "TAR.LZ4"
        case .gzip: "GZIP"
        case .bzip2: "BZIP2"
        case .xz: "XZ"
        case .lzma: "LZMA"
        case .lzip: "LZIP"
        case .compressZ: "Z"
        case .zstd: "ZSTD"
        case .lz4: "LZ4"
        case .brotli: "Brotli"
        case .cab: "CAB"
        case .wim: "WIM"
        case .iso: "ISO"
        case .cpio: "CPIO"
        case .pax: "PAX"
        case .ar: "AR"
        case .xar: "XAR"
        case .dmg: "DMG"
        case .appleArchive: "Apple Archive"
        case .jar: "JAR"
        case .war: "WAR"
        case .ear: "EAR"
        case .apk: "APK"
        case .ipa: "IPA"
        case .xpi: "XPI"
        case .appx: "APPX"
        case .msi: "MSI"
        case .xip: "XIP"
        case .cpgz: "CPGZ"
        case .unknown: "Unknown"
        }
    }

    public var defaultExtension: String {
        switch self {
        case .zip, .jar, .war, .ear, .apk, .ipa, .xpi, .appx: "zip"
        case .zipx: "zipx"
        case .sevenZip: "7z"
        case .rar, .rar5: "rar"
        case .tar: "tar"
        case .tarGz: "tar.gz"
        case .tarBz2: "tar.bz2"
        case .tarXz: "tar.xz"
        case .tarZstd: "tar.zst"
        case .tarLz4: "tar.lz4"
        case .gzip: "gz"
        case .bzip2: "bz2"
        case .xz: "xz"
        case .lzma: "lzma"
        case .lzip: "lz"
        case .compressZ: "Z"
        case .zstd: "zst"
        case .lz4: "lz4"
        case .brotli: "br"
        case .cab: "cab"
        case .wim: "wim"
        case .iso: "iso"
        case .cpio: "cpio"
        case .pax: "pax"
        case .ar: "a"
        case .xar: "xar"
        case .dmg: "dmg"
        case .appleArchive: "aar"
        case .msi: "msi"
        case .xip: "xip"
        case .cpgz: "cpgz"
        case .unknown: "archive"
        }
    }

    /// ZIP-derived containers share ZIP structure.
    public var treatedAsZipContainer: Bool {
        switch self {
        case .zip, .zipx, .jar, .war, .ear, .apk, .ipa, .xpi, .appx, .xip:
            true
        default:
            false
        }
    }

    public var isSingleFileCompression: Bool {
        switch self {
        case .gzip, .bzip2, .xz, .lzma, .lzip, .compressZ, .zstd, .lz4, .brotli:
            true
        default:
            false
        }
    }

    public var isTarFamily: Bool {
        switch self {
        case .tar, .tarGz, .tarBz2, .tarXz, .tarZstd, .tarLz4, .pax, .cpgz:
            true
        default:
            false
        }
    }
}
