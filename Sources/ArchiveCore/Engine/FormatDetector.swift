import Foundation

public struct FormatDetection: Sendable, Equatable {
    public var format: ArchiveFormat
    public var confidence: Double
    public var viaMagic: Bool
    public var viaExtension: Bool

    public init(format: ArchiveFormat, confidence: Double, viaMagic: Bool, viaExtension: Bool) {
        self.format = format
        self.confidence = confidence
        self.viaMagic = viaMagic
        self.viaExtension = viaExtension
    }
}

public enum FormatDetector {
    public static func detect(url: URL, maxBytes: Int = 512) -> FormatDetection {
        let extFormat = detectExtension(url)
        if let magic = detectMagic(url: url, maxBytes: maxBytes) {
            if magic == .tar || magic == .gzip || magic == .bzip2 || magic == .xz || magic == .zstd || magic == .lz4 {
                if let extFormat, extFormat.isTarFamily {
                    return FormatDetection(format: extFormat, confidence: 0.95, viaMagic: true, viaExtension: true)
                }
            }
            if magic.treatedAsZipContainer, let extFormat, extFormat.treatedAsZipContainer {
                return FormatDetection(format: extFormat, confidence: 0.95, viaMagic: true, viaExtension: true)
            }
            return FormatDetection(format: magic, confidence: 0.9, viaMagic: true, viaExtension: extFormat == magic)
        }
        if let extFormat {
            return FormatDetection(format: extFormat, confidence: 0.5, viaMagic: false, viaExtension: true)
        }
        return FormatDetection(format: .unknown, confidence: 0, viaMagic: false, viaExtension: false)
    }

    public static func detectExtension(_ url: URL) -> ArchiveFormat? {
        let name = url.lastPathComponent.lowercased()
        let pairs: [(String, ArchiveFormat)] = [
            (".tar.gz", .tarGz), (".tgz", .tarGz),
            (".tar.bz2", .tarBz2), (".tbz2", .tarBz2), (".tbz", .tarBz2),
            (".tar.xz", .tarXz), (".txz", .tarXz),
            (".tar.zst", .tarZstd), (".tar.zstd", .tarZstd),
            (".tar.lz4", .tarLz4),
            (".cpgz", .cpgz),
            (".tar", .tar),
            (".zipx", .zipx),
            (".zip", .zip),
            (".7z", .sevenZip),
            (".rar", .rar),
            (".gz", .gzip),
            (".bz2", .bzip2),
            (".xz", .xz),
            (".lzma", .lzma),
            (".lz", .lzip),
            (".zst", .zstd),
            (".zstd", .zstd),
            (".lz4", .lz4),
            (".br", .brotli),
            (".cab", .cab),
            (".wim", .wim),
            (".iso", .iso),
            (".cpio", .cpio),
            (".pax", .pax),
            (".a", .ar),
            (".ar", .ar),
            (".xar", .xar),
            (".dmg", .dmg),
            (".aar", .appleArchive),
            (".jar", .jar),
            (".war", .war),
            (".ear", .ear),
            (".apk", .apk),
            (".ipa", .ipa),
            (".xpi", .xpi),
            (".appx", .appx),
            (".msi", .msi),
            (".xip", .xip),
        ]
        for (suffix, format) in pairs where name.hasSuffix(suffix) {
            return format
        }
        if name.hasSuffix(".z") { return .compressZ }
        return nil
    }

    public static func detectMagic(url: URL, maxBytes: Int = 512) -> ArchiveFormat? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let prefix = (try? handle.read(upToCount: maxBytes)) ?? Data()
        return detectMagic(data: prefix, url: url)
    }

    public static func detectMagic(data: Data, url: URL? = nil) -> ArchiveFormat? {
        if data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]) {
            return .rar5
        }
        if data.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]) {
            return .rar
        }
        if data.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) {
            return .sevenZip
        }
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) || data.starts(with: [0x50, 0x4B, 0x05, 0x06]) || data.starts(with: [0x50, 0x4B, 0x07, 0x08]) {
            if let url, let ext = detectExtension(url), ext.treatedAsZipContainer {
                return ext
            }
            return .zip
        }
        if data.starts(with: [0x1F, 0x8B]) { return .gzip }
        if data.starts(with: [0x42, 0x5A, 0x68]) { return .bzip2 }
        if data.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) { return .xz }
        if data.starts(with: [0x28, 0xB5, 0x2F, 0xFD]) { return .zstd }
        if data.starts(with: [0x04, 0x22, 0x4D, 0x18]) { return .lz4 }
        if data.starts(with: [0x4D, 0x53, 0x43, 0x46]) { return .cab }
        if data.starts(with: [0x21, 0x3C, 0x61, 0x72, 0x63, 0x68, 0x3E]) { return .ar }
        if data.count > 8, data[0] == 0xCE, data[1] == 0xFA, data[2] == 0xED, data[3] == 0xFE {
            return nil
        }
        if looksLikeISO(data) { return .iso }
        if looksLikeTAR(data) { return .tar }
        if data.starts(with: [0x78, 0x61, 0x72, 0x21]) { return .xar }
        if data.starts(with: [0x4C, 0x5A, 0x49, 0x50]) { return .lzip }
        if data.count >= 2, data[0] == 0x1F, data[1] == 0x9D { return .compressZ }
        return nil
    }

    private static func looksLikeTAR(_ data: Data) -> Bool {
        guard data.count >= 262 else { return false }
        let ustar = data.subdata(in: 257..<262)
        return ustar == Data("ustar".utf8)
    }

    private static func looksLikeISO(_ data: Data) -> Bool {
        // ISO 9660 primary volume descriptor typically at sector 16 (0x8000) + 1.
        guard data.count > 0x8006 else { return false }
        let marker = data.subdata(in: 0x8001..<0x8006)
        return marker == Data("CD001".utf8)
    }

    public static func detectMultipart(url: URL) -> ArchiveVolumeInfo {
        let name = url.lastPathComponent
        let regexes = [
            #"^(.*)\.(7z|zip|rar)\.(\d{3})$"#,
            #"^(.*)\.part(\d+)\.rar$"#,
            #"^(.*)\.r(\d{2})$"#,
        ]
        for pattern in regexes {
            if let match = name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                _ = match
                return ArchiveVolumeInfo(
                    isMultipart: true,
                    missingVolumes: [],
                    firstVolumeName: name
                )
            }
        }
        return ArchiveVolumeInfo()
    }
}
