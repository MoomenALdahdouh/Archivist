import Foundation

public enum ArchiveEntryKind: String, Sendable, Codable, Hashable {
    case file
    case directory
    case symbolicLink
    case hardLink
    case other
}

public struct ArchiveEntry: Sendable, Identifiable, Hashable, Codable {
    public var id: String { path }

    public var path: String
    public var kind: ArchiveEntryKind
    public var uncompressedSize: UInt64
    public var compressedSize: UInt64?
    public var modified: Date?
    public var created: Date?
    public var posixPermissions: UInt16?
    public var crc32: UInt32?
    public var isEncrypted: Bool
    public var symlinkTarget: String?
    public var comment: String?
    public var compressionMethod: String?

    public init(
        path: String,
        kind: ArchiveEntryKind,
        uncompressedSize: UInt64 = 0,
        compressedSize: UInt64? = nil,
        modified: Date? = nil,
        created: Date? = nil,
        posixPermissions: UInt16? = nil,
        crc32: UInt32? = nil,
        isEncrypted: Bool = false,
        symlinkTarget: String? = nil,
        comment: String? = nil,
        compressionMethod: String? = nil
    ) {
        self.path = path
        self.kind = kind
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.modified = modified
        self.created = created
        self.posixPermissions = posixPermissions
        self.crc32 = crc32
        self.isEncrypted = isEncrypted
        self.symlinkTarget = symlinkTarget
        self.comment = comment
        self.compressionMethod = compressionMethod
    }

    public var name: String {
        (path as NSString).lastPathComponent
    }

    public var parentPath: String {
        let parent = (path as NSString).deletingLastPathComponent
        if parent == "." { return "" }
        return parent
    }

    public var ratio: Double? {
        guard let compressedSize, uncompressedSize > 0 else { return nil }
        return Double(compressedSize) / Double(uncompressedSize)
    }

    public var isDirectory: Bool { kind == .directory }
}

public struct ArchiveVolumeInfo: Sendable, Hashable, Codable {
    public var isMultipart: Bool
    public var totalVolumes: Int?
    public var missingVolumes: [String]
    public var firstVolumeName: String?

    public init(
        isMultipart: Bool = false,
        totalVolumes: Int? = nil,
        missingVolumes: [String] = [],
        firstVolumeName: String? = nil
    ) {
        self.isMultipart = isMultipart
        self.totalVolumes = totalVolumes
        self.missingVolumes = missingVolumes
        self.firstVolumeName = firstVolumeName
    }
}

public struct ArchiveInfo: Sendable, Hashable, Codable {
    public var format: ArchiveFormat
    public var formatName: String
    public var backend: BackendKind
    public var capabilities: FormatCapabilities
    public var entryCount: UInt64
    public var totalUncompressedSize: UInt64
    public var compressedSize: UInt64
    public var isEncrypted: Bool
    public var encryptsFilenames: Bool
    public var comment: String?
    public var volume: ArchiveVolumeInfo
    public var warnings: [String]
    public var compressionMethod: String?

    public init(
        format: ArchiveFormat,
        formatName: String? = nil,
        backend: BackendKind,
        capabilities: FormatCapabilities,
        entryCount: UInt64 = 0,
        totalUncompressedSize: UInt64 = 0,
        compressedSize: UInt64 = 0,
        isEncrypted: Bool = false,
        encryptsFilenames: Bool = false,
        comment: String? = nil,
        volume: ArchiveVolumeInfo = ArchiveVolumeInfo(),
        warnings: [String] = [],
        compressionMethod: String? = nil
    ) {
        self.format = format
        self.formatName = formatName ?? format.displayName
        self.backend = backend
        self.capabilities = capabilities
        self.entryCount = entryCount
        self.totalUncompressedSize = totalUncompressedSize
        self.compressedSize = compressedSize
        self.isEncrypted = isEncrypted
        self.encryptsFilenames = encryptsFilenames
        self.comment = comment
        self.volume = volume
        self.warnings = warnings
        self.compressionMethod = compressionMethod
    }

    public var compressionRatio: Double? {
        guard totalUncompressedSize > 0, compressedSize > 0 else { return nil }
        return Double(compressedSize) / Double(totalUncompressedSize)
    }
}

public struct ArchiveIntegrityResult: Sendable, Hashable, Codable {
    public enum Status: String, Sendable, Codable {
        case ok
        case warnings
        case corrupted
        case crcMismatch
        case missingVolume
        case encryptedUnverifiable
        case wrongPassword
    }

    public var status: Status
    public var testedEntries: UInt64
    public var warnings: [String]
    public var errors: [String]

    public init(
        status: Status,
        testedEntries: UInt64 = 0,
        warnings: [String] = [],
        errors: [String] = []
    ) {
        self.status = status
        self.testedEntries = testedEntries
        self.warnings = warnings
        self.errors = errors
    }

    public var userMessage: String {
        switch status {
        case .ok: "Archive OK"
        case .warnings: "Archive contains warnings"
        case .corrupted: "Archive is corrupted"
        case .crcMismatch: "CRC mismatch"
        case .missingVolume: "Missing volume"
        case .encryptedUnverifiable: "Encrypted entries could not be verified"
        case .wrongPassword: "Incorrect password"
        }
    }
}
