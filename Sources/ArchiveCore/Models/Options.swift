import Foundation

public enum OverwritePolicy: String, Sendable, CaseIterable, Codable, Identifiable {
    case ask
    case alwaysReplace
    case neverReplace
    case replaceIfNewer
    case renameAutomatically

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ask: "Ask"
        case .alwaysReplace: "Always Replace"
        case .neverReplace: "Never Replace"
        case .replaceIfNewer: "Replace if Newer"
        case .renameAutomatically: "Rename Automatically"
        }
    }
}

public enum OverwriteDecision: String, Sendable, Codable {
    case replace
    case skip
    case rename
    case cancel
}

public struct SafetyLimits: Sendable, Hashable, Codable {
    public var maximumExtractedBytes: UInt64
    public var maximumFileCount: UInt64
    public var maximumNestingDepth: Int
    public var maximumPathLength: Int
    public var bombRatio: Double
    public var bombMinimumUncompressedBytes: UInt64

    public init(
        maximumExtractedBytes: UInt64 = 1_099_511_627_776,
        maximumFileCount: UInt64 = 1_000_000,
        maximumNestingDepth: Int = 32,
        maximumPathLength: Int = 1024,
        bombRatio: Double = 100,
        bombMinimumUncompressedBytes: UInt64 = 1_073_741_824
    ) {
        self.maximumExtractedBytes = maximumExtractedBytes
        self.maximumFileCount = maximumFileCount
        self.maximumNestingDepth = maximumNestingDepth
        self.maximumPathLength = maximumPathLength
        self.bombRatio = bombRatio
        self.bombMinimumUncompressedBytes = bombMinimumUncompressedBytes
    }

    public static let `default` = SafetyLimits()
}

public struct ExtractionOptions: Sendable {
    public var selectedPaths: Set<String>
    public var extractAll: Bool
    public var preserveFolders: Bool
    public var preservePermissions: Bool
    public var preserveTimestamps: Bool
    public var preserveSymlinks: Bool
    public var preserveExtendedAttributes: Bool
    public var overwrite: OverwritePolicy
    public var password: String?
    public var safety: SafetyLimits
    public var overwriteHandler: (@Sendable (URL) async -> OverwriteDecision)?

    public init(
        selectedPaths: Set<String> = [],
        extractAll: Bool = true,
        preserveFolders: Bool = true,
        preservePermissions: Bool = true,
        preserveTimestamps: Bool = true,
        preserveSymlinks: Bool = true,
        preserveExtendedAttributes: Bool = true,
        overwrite: OverwritePolicy = .ask,
        password: String? = nil,
        safety: SafetyLimits = .default,
        overwriteHandler: (@Sendable (URL) async -> OverwriteDecision)? = nil
    ) {
        self.selectedPaths = selectedPaths
        self.extractAll = extractAll
        self.preserveFolders = preserveFolders
        self.preservePermissions = preservePermissions
        self.preserveTimestamps = preserveTimestamps
        self.preserveSymlinks = preserveSymlinks
        self.preserveExtendedAttributes = preserveExtendedAttributes
        self.overwrite = overwrite
        self.password = password
        self.safety = safety
        self.overwriteHandler = overwriteHandler
    }

    public func includes(path: String) -> Bool {
        if extractAll { return true }
        if selectedPaths.contains(path) { return true }
        for selected in selectedPaths {
            let prefix = selected.hasSuffix("/") ? selected : selected + "/"
            if path.hasPrefix(prefix) { return true }
        }
        return false
    }
}

public enum CompressionLevel: String, Sendable, CaseIterable, Codable, Identifiable {
    case store
    case fastest
    case fast
    case normal
    case maximum
    case ultra

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .store: "Store"
        case .fastest: "Fastest"
        case .fast: "Fast"
        case .normal: "Normal"
        case .maximum: "Maximum"
        case .ultra: "Ultra"
        }
    }

    /// libarchive / gzip-style 0...9 mapping. Store is 0.
    public var numericLevel: Int {
        switch self {
        case .store: 0
        case .fastest: 1
        case .fast: 3
        case .normal: 6
        case .maximum: 8
        case .ultra: 9
        }
    }
}

public enum EncryptionMethod: String, Sendable, CaseIterable, Codable, Identifiable {
    case none
    case zipCrypto
    case zipAES
    case sevenZipAES256

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: "None"
        case .zipCrypto: "ZIP Crypto (legacy, weak)"
        case .zipAES: "ZIP AES"
        case .sevenZipAES256: "7Z AES-256"
        }
    }
}

public struct SplitVolumeSize: Sendable, Hashable, Codable {
    public var bytes: UInt64?

    public init(bytes: UInt64?) {
        self.bytes = bytes
    }

    public static let none = SplitVolumeSize(bytes: nil)
    public static let mb10 = SplitVolumeSize(bytes: 10 * 1_048_576)
    public static let mb50 = SplitVolumeSize(bytes: 50 * 1_048_576)
    public static let mb100 = SplitVolumeSize(bytes: 100 * 1_048_576)
    public static let mb500 = SplitVolumeSize(bytes: 500 * 1_048_576)
    public static let gb1 = SplitVolumeSize(bytes: 1_073_741_824)
    public static let gb4 = SplitVolumeSize(bytes: 4_294_967_296)

    public var displayName: String {
        guard let bytes else { return "None" }
        return ByteCountFormat.string(from: bytes)
    }
}

public struct CompressionOptions: Sendable {
    public var format: ArchiveFormat
    public var level: CompressionLevel
    public var password: String?
    public var encryption: EncryptionMethod
    public var encryptFilenames: Bool
    public var split: SplitVolumeSize
    public var preservePermissions: Bool
    public var preserveTimestamps: Bool
    public var preserveExtendedAttributes: Bool
    public var preserveSymlinks: Bool
    public var followSymlinks: Bool

    public init(
        format: ArchiveFormat = .zip,
        level: CompressionLevel = .normal,
        password: String? = nil,
        encryption: EncryptionMethod = .none,
        encryptFilenames: Bool = false,
        split: SplitVolumeSize = .none,
        preservePermissions: Bool = true,
        preserveTimestamps: Bool = true,
        preserveExtendedAttributes: Bool = true,
        preserveSymlinks: Bool = true,
        followSymlinks: Bool = false
    ) {
        self.format = format
        self.level = level
        self.password = password
        self.encryption = encryption
        self.encryptFilenames = encryptFilenames
        self.split = split
        self.preservePermissions = preservePermissions
        self.preserveTimestamps = preserveTimestamps
        self.preserveExtendedAttributes = preserveExtendedAttributes
        self.preserveSymlinks = preserveSymlinks
        self.followSymlinks = followSymlinks
    }
}

public enum ByteCountFormat {
    public static func string(from bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }
}
