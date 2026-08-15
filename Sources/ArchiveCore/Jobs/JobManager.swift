import Foundation

public enum JobStatus: String, Sendable, Codable, Hashable {
    case queued
    case preparing
    case running
    case paused
    case cancelling
    case cancelled
    case completed
    case completedWithWarnings
    case failed

    public var displayName: String {
        switch self {
        case .queued: "Queued"
        case .preparing: "Preparing"
        case .running: "Running"
        case .paused: "Paused"
        case .cancelling: "Stopping…"
        case .cancelled: "Cancelled"
        case .completed: "Completed"
        case .completedWithWarnings: "Completed with warnings"
        case .failed: "Failed"
        }
    }

    public var isFinished: Bool {
        switch self {
        case .cancelled, .completed, .completedWithWarnings, .failed: true
        default: false
        }
    }
}

public struct ArchiveJob: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var operation: ArchiveOperationKind
    public var sourceName: String
    public var destinationName: String?
    public var status: JobStatus
    public var progress: ProgressSnapshot
    public var warnings: [String]
    public var errorMessage: String?
    public var errorCode: String?
    public var startedAt: Date?
    public var finishedAt: Date?

    public init(
        id: UUID = UUID(),
        operation: ArchiveOperationKind,
        sourceName: String,
        destinationName: String? = nil,
        status: JobStatus = .queued,
        progress: ProgressSnapshot = ProgressSnapshot(isIndeterminate: true),
        warnings: [String] = [],
        errorMessage: String? = nil,
        errorCode: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.operation = operation
        self.sourceName = sourceName
        self.destinationName = destinationName
        self.status = status
        self.progress = progress
        self.warnings = warnings
        self.errorMessage = errorMessage
        self.errorCode = errorCode
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public actor JobManager {
    public static let shared = JobManager()

    private var jobs: [UUID: ArchiveJob] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var continuations: [UUID: AsyncStream<ArchiveJob>.Continuation] = [:]
    private var order: [UUID] = []

    public init() {}

    public func snapshot() -> [ArchiveJob] {
        order.compactMap { jobs[$0] }
    }

    public func job(id: UUID) -> ArchiveJob? {
        jobs[id]
    }

    public func updates() -> AsyncStream<ArchiveJob> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    public func submit(
        operation: ArchiveOperationKind,
        sourceName: String,
        destinationName: String? = nil,
        work: @escaping @Sendable (UUID, @escaping ProgressHandler) async throws -> Void
    ) -> UUID {
        let id = UUID()
        let job = ArchiveJob(id: id, operation: operation, sourceName: sourceName, destinationName: destinationName)
        jobs[id] = job
        order.append(id)
        publish(job)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.mark(id, status: .preparing)
            do {
                try Task.checkCancellation()
                await self.mark(id, status: .running, started: true)
                let handler: ProgressHandler = { snapshot in
                    Task { await self.updateProgress(id, snapshot) }
                }
                try await work(id, handler)
                if Task.isCancelled {
                    await self.finish(id, status: .cancelled, error: ArchiveError.cancelled)
                } else {
                    let current = await self.job(id: id)
                    let status: JobStatus = (current?.warnings.isEmpty == false) ? .completedWithWarnings : .completed
                    await self.finish(id, status: status, error: nil)
                }
            } catch is CancellationError {
                await self.finish(id, status: .cancelled, error: ArchiveError.cancelled)
            } catch let error as ArchiveError {
                if case .cancelled = error {
                    await self.finish(id, status: .cancelled, error: error)
                } else {
                    await self.finish(id, status: .failed, error: error)
                }
            } catch {
                await self.finish(id, status: .failed, error: ArchiveError.backendFailure(error.localizedDescription))
            }
        }
        tasks[id] = task
        _ = job
        return id
    }

    public func cancel(_ id: UUID) {
        guard var job = jobs[id], !job.status.isFinished else { return }
        job.status = .cancelling
        jobs[id] = job
        publish(job)
        tasks[id]?.cancel()
    }

    public func cancelAll() {
        for id in order {
            cancel(id)
        }
    }

    public func addWarning(_ id: UUID, _ warning: String) {
        guard var job = jobs[id] else { return }
        job.warnings.append(warning)
        jobs[id] = job
        publish(job)
    }

    private func mark(_ id: UUID, status: JobStatus, started: Bool = false) {
        guard var job = jobs[id] else { return }
        job.status = status
        if started { job.startedAt = Date() }
        jobs[id] = job
        publish(job)
    }

    private func updateProgress(_ id: UUID, _ snapshot: ProgressSnapshot) {
        guard var job = jobs[id] else { return }
        job.progress = snapshot
        jobs[id] = job
        publish(job)
    }

    private func finish(_ id: UUID, status: JobStatus, error: ArchiveError?) {
        guard var job = jobs[id] else { return }
        job.status = status
        job.finishedAt = Date()
        if let error {
            job.errorMessage = error.userMessage
            job.errorCode = error.errorCode
        }
        jobs[id] = job
        tasks[id] = nil
        publish(job)
    }

    private func publish(_ job: ArchiveJob) {
        for continuation in continuations.values {
            continuation.yield(job)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
