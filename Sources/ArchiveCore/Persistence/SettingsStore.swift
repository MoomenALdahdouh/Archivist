import Foundation

public struct AppSettings: Sendable, Codable, Equatable {
    public var defaultExtractionLocation: URL?
    public var defaultCompressionLocation: URL?
    public var openArchivesAutomatically: Bool
    public var confirmDestructiveOperations: Bool
    public var overwritePolicy: OverwritePolicy
    public var preserveMetadata: Bool
    public var preservePermissions: Bool
    public var preserveSymlinks: Bool
    public var safety: SafetyLimits
    public var defaultFormat: ArchiveFormat
    public var defaultCompressionLevel: CompressionLevel
    public var defaultSplit: SplitVolumeSize
    public var rememberPasswords: Bool
    public var useKeychain: Bool
    public var appearance: AppearanceMode
    public var loggingEnabled: Bool
    public var finderExtractHere: Bool
    public var finderCompressRAR: Bool
    public var finderCompressZIP: Bool
    public var finderCompress7Z: Bool
    public var verifyAfterCreate: Bool

    public init() {
        self.defaultExtractionLocation = nil
        self.defaultCompressionLocation = nil
        self.openArchivesAutomatically = true
        self.confirmDestructiveOperations = true
        self.overwritePolicy = .ask
        self.preserveMetadata = true
        self.preservePermissions = true
        self.preserveSymlinks = true
        self.safety = .default
        self.defaultFormat = .zip
        self.defaultCompressionLevel = .normal
        self.defaultSplit = .none
        self.rememberPasswords = false
        self.useKeychain = false
        self.appearance = .system
        self.loggingEnabled = true
        self.finderExtractHere = true
        self.finderCompressRAR = true
        self.finderCompressZIP = true
        self.finderCompress7Z = true
        self.verifyAfterCreate = false
    }

    public enum AppearanceMode: String, Sendable, Codable, CaseIterable, Identifiable {
        case system, light, dark
        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .system: "Follow system"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
    }
}

public actor SettingsStore {
    public static let shared = SettingsStore()
    private let url: URL
    private var settings: AppSettings

    public init(url: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Archivist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = url ?? dir.appendingPathComponent("settings.json")
        if let data = try? Data(contentsOf: self.url),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    public func current() -> AppSettings { settings }

    public func update(_ newSettings: AppSettings) throws {
        settings = newSettings
        let data = try JSONEncoder().encode(settings)
        try data.write(to: url, options: .atomic)
    }
}

public struct HistoryRecord: Sendable, Identifiable, Codable, Hashable {
    public var id: UUID
    public var date: Date
    public var archive: String
    public var operation: ArchiveOperationKind
    public var result: String
    public var duration: TimeInterval
    public var destination: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        archive: String,
        operation: ArchiveOperationKind,
        result: String,
        duration: TimeInterval,
        destination: String? = nil
    ) {
        self.id = id
        self.date = date
        self.archive = archive
        self.operation = operation
        self.result = result
        self.duration = duration
        self.destination = destination
    }
}

public actor HistoryStore {
    public static let shared = HistoryStore()
    private var records: [HistoryRecord] = []
    private let url: URL

    public init(url: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Archivist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = url ?? dir.appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: self.url),
           let decoded = try? JSONDecoder().decode([HistoryRecord].self, from: data) {
            self.records = decoded
        }
    }

    public func all() -> [HistoryRecord] { records.reversed() }

    public func append(_ record: HistoryRecord) {
        var sanitized = record
        sanitized.archive = ArchiveError.redact(sanitized.archive)
        records.append(sanitized)
        persist()
    }

    public func clear() {
        records = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
