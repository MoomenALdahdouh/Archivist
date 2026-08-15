import Foundation

public struct BackendRegistry: Sendable {
    public var backends: [any ArchiveBackend]

    public init(backends: [any ArchiveBackend]) {
        self.backends = backends
    }

    public func backend(for format: ArchiveFormat, wantsCreate: Bool = false, encrypted: Bool = false) -> (any ArchiveBackend)? {
        let ranked = backends.filter { $0.supportedFormats.contains(format) }
        if encrypted {
            if let match = ranked.first(where: { $0.capabilities(for: format).password }) {
                return match
            }
        }
        if wantsCreate {
            if let match = ranked.first(where: { $0.capabilities(for: format).create }) {
                return match
            }
        }
        return ranked.first
    }
}

public actor ArchiveEngine {
    private let registry: BackendRegistry
    private let jobs: JobManager
    private let temps: TempDirectoryManager
    private let log = ArchiveLogger(category: .engine)

    public init(
        registry: BackendRegistry? = nil,
        jobs: JobManager = .shared,
        temps: TempDirectoryManager = .shared
    ) {
        self.registry = registry ?? BackendRegistry(backends: [])
        self.jobs = jobs
        self.temps = temps
    }

    public func inspect(_ source: URL, password: String? = nil) async throws -> ArchiveInfo {
        let detection = FormatDetector.detect(url: source)
        guard detection.format != .unknown else { throw ArchiveError.notAnArchive }
        let backend = try resolve(format: detection.format, encrypted: password != nil)
        var info = try await backend.inspect(source, password: password)
        let volume = FormatDetector.detectMultipart(url: source)
        if volume.isMultipart {
            info.volume = volume
        }
        info.compressedSize = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? UInt64) ?? info.compressedSize
        if info.compressedSize == 0 {
            if let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                info.compressedSize = UInt64(size)
            }
        }
        return info
    }

    public func list(_ source: URL, password: String? = nil) async throws -> [ArchiveEntry] {
        let info = try await inspect(source, password: password)
        let backend = try resolve(format: info.format, encrypted: info.isEncrypted || password != nil)
        var entries: [ArchiveEntry] = []
        for try await entry in backend.listContents(source, password: password) {
            try Task.checkCancellation()
            entries.append(entry)
        }
        return entries
    }

    public func extract(
        _ source: URL,
        to destination: URL,
        options: ExtractionOptions,
        progress: @escaping ProgressHandler = { _ in }
    ) async throws {
        let info = try await inspect(source, password: options.password)
        if !info.volume.missingVolumes.isEmpty {
            throw ArchiveError.missingVolume(info.volume.missingVolumes.joined(separator: ", "))
        }
        try ExtractionGuard(limits: options.safety).checkBomb(
            compressed: info.compressedSize,
            uncompressed: info.totalUncompressedSize
        )
        try ExtractionGuard(limits: options.safety).checkCounts(
            files: info.entryCount,
            bytes: info.totalUncompressedSize
        )
        if info.totalUncompressedSize > 0 {
            _ = try DiskSpaceChecker.evaluate(required: info.totalUncompressedSize, destination: destination)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        if !DiskSpaceChecker.destinationIsWritable(destination) {
            throw ArchiveError.destinationNotWritable(destination.path)
        }
        let backend = try resolve(format: info.format, encrypted: info.isEncrypted || options.password != nil)
        try await backend.extract(source, to: destination, options: options, progress: progress)
    }

    public func create(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions,
        progress: @escaping ProgressHandler = { _ in }
    ) async throws {
        guard options.format != .rar && options.format != .rar5 else {
            throw ArchiveError.formatNotCreatable(options.format)
        }
        let backend = try resolve(format: options.format, wantsCreate: true, encrypted: options.password != nil)
        let caps = backend.capabilities(for: options.format)
        if !caps.create {
            throw ArchiveError.formatNotCreatable(options.format)
        }
        if options.split.bytes != nil && !caps.split {
            throw ArchiveError.backendFailure("Split volumes are not supported for \(options.format.displayName).")
        }
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try await backend.create(from: sources, destination: destination, options: options, progress: progress)
    }

    public func test(
        _ source: URL,
        password: String? = nil,
        progress: @escaping ProgressHandler = { _ in }
    ) async throws -> ArchiveIntegrityResult {
        let info = try await inspect(source, password: password)
        let backend = try resolve(format: info.format, encrypted: info.isEncrypted || password != nil)
        return try await backend.test(source, password: password, progress: progress)
    }

    public func enqueueExtract(
        _ source: URL,
        to destination: URL,
        options: ExtractionOptions
    ) async -> UUID {
        await jobs.submit(operation: .extract, sourceName: source.lastPathComponent, destinationName: destination.path) { _, progress in
            try await self.extract(source, to: destination, options: options, progress: { progress($0) })
        }
    }

    public func enqueueCreate(
        from sources: [URL],
        destination: URL,
        options: CompressionOptions
    ) async -> UUID {
        await jobs.submit(operation: .create, sourceName: destination.lastPathComponent, destinationName: destination.path) { _, progress in
            try await self.create(from: sources, destination: destination, options: options, progress: { progress($0) })
        }
    }

    public func enqueueTest(_ source: URL, password: String?) async -> UUID {
        await jobs.submit(operation: .test, sourceName: source.lastPathComponent) { _, progress in
            _ = try await self.test(source, password: password, progress: { progress($0) })
        }
    }

    private func resolve(
        format: ArchiveFormat,
        wantsCreate: Bool = false,
        encrypted: Bool = false
    ) throws -> any ArchiveBackend {
        if registry.backends.isEmpty {
            throw ArchiveError.backendFailure("No archive backends are registered.")
        }
        guard let backend = registry.backend(for: format, wantsCreate: wantsCreate, encrypted: encrypted) else {
            throw ArchiveError.unsupportedFormat(format)
        }
        return backend
    }
}

public enum UniqueName {
    public static func next(for url: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) { return url }
        let ext = url.pathExtension
        let base = ext.isEmpty ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()
        var index = 1
        while true {
            let candidateName = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            let candidate = dir.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
            if index > 10_000 { return dir.appendingPathComponent("\(base)-\(UUID().uuidString).\(ext)") }
        }
    }
}
