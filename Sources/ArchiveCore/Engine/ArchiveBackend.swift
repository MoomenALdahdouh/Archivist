import Foundation

public protocol ArchiveBackend: Sendable {
    var kind: BackendKind { get }
    var supportedFormats: Set<ArchiveFormat> { get }
    var isAvailable: Bool { get }

    func capabilities(for format: ArchiveFormat) -> FormatCapabilities

    func inspect(_ source: URL, password: String?) async throws -> ArchiveInfo

    func listContents(
        _ source: URL,
        password: String?
    ) -> AsyncThrowingStream<ArchiveEntry, any Error>

    func extract(
        _ source: URL,
        to destination: URL,
        options: ExtractionOptions,
        progress: @escaping ProgressHandler
    ) async throws

    func create(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler
    ) async throws

    func test(
        _ source: URL,
        password: String?,
        progress: @escaping ProgressHandler
    ) async throws -> ArchiveIntegrityResult
}

public extension ArchiveBackend {
    var isAvailable: Bool { true }

    func inspect(_ source: URL) async throws -> ArchiveInfo {
        try await inspect(source, password: nil)
    }

    func listContents(_ source: URL) -> AsyncThrowingStream<ArchiveEntry, any Error> {
        listContents(source, password: nil)
    }
}

public enum ArchiveOperationKind: String, Sendable, Codable {
    case inspect
    case list
    case extract
    case create
    case test
    case modify
}

public struct ProgressSnapshot: Sendable, Hashable {
    public var fraction: Double?
    public var completedBytes: UInt64
    public var totalBytes: UInt64?
    public var currentItem: String?
    public var itemsCompleted: UInt64
    public var itemsTotal: UInt64?
    public var bytesPerSecond: Double?
    public var estimatedRemaining: TimeInterval?
    public var isIndeterminate: Bool

    public init(
        fraction: Double? = nil,
        completedBytes: UInt64 = 0,
        totalBytes: UInt64? = nil,
        currentItem: String? = nil,
        itemsCompleted: UInt64 = 0,
        itemsTotal: UInt64? = nil,
        bytesPerSecond: Double? = nil,
        estimatedRemaining: TimeInterval? = nil,
        isIndeterminate: Bool = false
    ) {
        self.fraction = fraction
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
        self.currentItem = currentItem
        self.itemsCompleted = itemsCompleted
        self.itemsTotal = itemsTotal
        self.bytesPerSecond = bytesPerSecond
        self.estimatedRemaining = estimatedRemaining
        self.isIndeterminate = isIndeterminate
    }

    public var percentText: String {
        if isIndeterminate { return "…" }
        guard let fraction else { return "…" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    public var bytesText: String {
        if let totalBytes {
            return "\(ByteCountFormat.string(from: completedBytes)) / \(ByteCountFormat.string(from: totalBytes))"
        }
        return ByteCountFormat.string(from: completedBytes)
    }

    public var speedText: String {
        guard let bytesPerSecond, bytesPerSecond > 0 else { return "" }
        return "\(ByteCountFormat.string(from: UInt64(bytesPerSecond)))/s"
    }

    public var etaText: String {
        guard let estimatedRemaining, estimatedRemaining.isFinite, estimatedRemaining > 0 else { return "" }
        let seconds = Int(estimatedRemaining.rounded())
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "ETA %d:%02d:%02d", h, m, s)
        }
        return String(format: "ETA %02d:%02d", m, s)
    }
}

public typealias ProgressHandler = @Sendable (ProgressSnapshot) -> Void

public struct ProgressEngine: Sendable {
    private let started = Date()

    public init() {}

    public func snapshot(
        completedBytes: UInt64,
        totalBytes: UInt64?,
        currentItem: String? = nil,
        itemsCompleted: UInt64 = 0,
        itemsTotal: UInt64? = nil,
        isIndeterminate: Bool = false
    ) -> ProgressSnapshot {
        let elapsed = Date().timeIntervalSince(started)
        let speed = elapsed > 0.2 ? Double(completedBytes) / elapsed : nil
        var fraction: Double?
        var eta: TimeInterval?
        var indeterminate = isIndeterminate
        if !isIndeterminate, let totalBytes, totalBytes > 0 {
            fraction = min(1.0, Double(completedBytes) / Double(totalBytes))
            if let speed, speed > 0, completedBytes < totalBytes {
                eta = Double(totalBytes - completedBytes) / speed
            }
        } else if totalBytes == nil || totalBytes == 0 {
            indeterminate = true
        }
        return ProgressSnapshot(
            fraction: fraction,
            completedBytes: completedBytes,
            totalBytes: totalBytes,
            currentItem: currentItem,
            itemsCompleted: itemsCompleted,
            itemsTotal: itemsTotal,
            bytesPerSecond: speed,
            estimatedRemaining: eta,
            isIndeterminate: indeterminate
        )
    }
}
