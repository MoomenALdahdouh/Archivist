import Foundation
import OSLog

public enum ArchiveLogCategory: String, Sendable {
    case engine = "archive.engine"
    case extraction = "archive.extraction"
    case compression = "archive.compression"
    case security = "archive.security"
    case filesystem = "archive.filesystem"
    case ui = "archive.ui"
    case finder = "archive.finder"
    case backend = "archive.backend"
    case performance = "archive.performance"
}

public struct ArchiveLogger: Sendable {
    public static let subsystem = "app.archivist.Archivist"

    private let logger: Logger

    public init(category: ArchiveLogCategory) {
        self.logger = Logger(subsystem: Self.subsystem, category: category.rawValue)
    }

    public func debug(_ message: String) {
        logger.debug("\(ArchiveError.redact(message), privacy: .public)")
    }

    public func info(_ message: String) {
        logger.info("\(ArchiveError.redact(message), privacy: .public)")
    }

    public func warning(_ message: String) {
        logger.warning("\(ArchiveError.redact(message), privacy: .public)")
    }

    public func error(_ message: String) {
        logger.error("\(ArchiveError.redact(message), privacy: .public)")
    }

    public func fault(_ message: String) {
        logger.fault("\(ArchiveError.redact(message), privacy: .public)")
    }
}
