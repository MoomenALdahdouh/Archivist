import Foundation
import ArchiveCore
import CLibArchive

enum LibArchive {
    static let ok = Int32(ARCHIVE_OK)
    static let eof = Int32(ARCHIVE_EOF)
    static let warn = Int32(ARCHIVE_WARN)
    static let failed = Int32(ARCHIVE_FAILED)
    static let fatal = Int32(ARCHIVE_FATAL)
    static let retry = Int32(ARCHIVE_RETRY)

    static let aeIFMT: UInt32 = 0o170000
    static let aeIFREG: UInt32 = 0o100000
    static let aeIFLNK: UInt32 = 0o120000
    static let aeIFDIR: UInt32 = 0o040000
    static let aeIFCHR: UInt32 = 0o020000
    static let aeIFBLK: UInt32 = 0o060000
    static let aeIFIFO: UInt32 = 0o010000
    static let aeIFSOCK: UInt32 = 0o140000

    static func string(_ ptr: UnsafePointer<CChar>?) -> String? {
        guard let ptr else { return nil }
        return String(cString: ptr)
    }

    static func check(_ status: Int32, _ archive: OpaquePointer?, allowWarn: Bool = true) throws {
        if status == ok || status == eof { return }
        if status == warn && allowWarn { return }
        let message = string(archive_error_string(archive)) ?? "libarchive error \(status)"
        if status == eof {
            throw ArchiveError.unexpectedEnd
        }
        throw ArchiveError.fromBackendMessage(message)
    }

    static func withPath<T>(_ url: URL, _ body: (UnsafePointer<CChar>) throws -> T) throws -> T {
        try url.withUnsafeFileSystemRepresentation { ptr in
            guard let ptr else { throw ArchiveError.io("Invalid filesystem path") }
            return try body(ptr)
        }
    }
}

enum LibArchiveFormatMap {
    static func write(archive: OpaquePointer, format: ArchiveFormat, level: CompressionLevel) throws {
        switch format {
        case .zip, .zipx, .jar, .war, .ear, .apk, .ipa, .xpi, .appx:
            try LibArchive.check(archive_write_set_format_zip(archive), archive)
            let compression = level == .store ? "store" : "deflate"
            _ = archive_write_set_format_option(archive, "zip", "compression", compression)
            _ = archive_write_set_format_option(archive, "zip", "compression-level", String(level.numericLevel))
        case .sevenZip:
            try LibArchive.check(archive_write_set_format_7zip(archive), archive)
            _ = archive_write_set_format_option(archive, "7zip", "compression", level == .store ? "copy" : "lzma2")
        case .tar, .pax:
            try LibArchive.check(archive_write_set_format_pax_restricted(archive), archive)
        case .tarGz:
            try LibArchive.check(archive_write_set_format_pax_restricted(archive), archive)
            try LibArchive.check(archive_write_add_filter_gzip(archive), archive)
            _ = archive_write_set_filter_option(archive, "gzip", "compression-level", String(level.numericLevel))
        case .tarBz2:
            try LibArchive.check(archive_write_set_format_pax_restricted(archive), archive)
            try LibArchive.check(archive_write_add_filter_bzip2(archive), archive)
        case .tarXz:
            try LibArchive.check(archive_write_set_format_pax_restricted(archive), archive)
            try LibArchive.check(archive_write_add_filter_xz(archive), archive)
        case .tarZstd:
            try LibArchive.check(archive_write_set_format_pax_restricted(archive), archive)
            try LibArchive.check(archive_write_add_filter_zstd(archive), archive)
        case .tarLz4:
            try LibArchive.check(archive_write_set_format_pax_restricted(archive), archive)
            try LibArchive.check(archive_write_add_filter_lz4(archive), archive)
        case .gzip:
            try LibArchive.check(archive_write_set_format_raw(archive), archive)
            try LibArchive.check(archive_write_add_filter_gzip(archive), archive)
            _ = archive_write_set_filter_option(archive, "gzip", "compression-level", String(max(1, level.numericLevel)))
        case .bzip2:
            try LibArchive.check(archive_write_set_format_raw(archive), archive)
            try LibArchive.check(archive_write_add_filter_bzip2(archive), archive)
        case .xz:
            try LibArchive.check(archive_write_set_format_raw(archive), archive)
            try LibArchive.check(archive_write_add_filter_xz(archive), archive)
        case .lzma:
            try LibArchive.check(archive_write_set_format_raw(archive), archive)
            try LibArchive.check(archive_write_add_filter_lzma(archive), archive)
        case .lzip:
            try LibArchive.check(archive_write_set_format_raw(archive), archive)
            try LibArchive.check(archive_write_add_filter_lzip(archive), archive)
        case .zstd:
            try LibArchive.check(archive_write_set_format_raw(archive), archive)
            try LibArchive.check(archive_write_add_filter_zstd(archive), archive)
        case .lz4:
            try LibArchive.check(archive_write_set_format_raw(archive), archive)
            try LibArchive.check(archive_write_add_filter_lz4(archive), archive)
        case .iso:
            try LibArchive.check(archive_write_set_format_iso9660(archive), archive)
        case .cpio:
            try LibArchive.check(archive_write_set_format_cpio_newc(archive), archive)
        case .ar:
            try LibArchive.check(archive_write_set_format_ar_bsd(archive), archive)
        case .cpgz:
            try LibArchive.check(archive_write_set_format_cpio_newc(archive), archive)
            try LibArchive.check(archive_write_add_filter_gzip(archive), archive)
        default:
            throw ArchiveError.formatNotCreatable(format)
        }
    }

    static func readFormatName(_ archive: OpaquePointer?) -> String {
        LibArchive.string(archive_format_name(archive)) ?? "unknown"
    }
}
