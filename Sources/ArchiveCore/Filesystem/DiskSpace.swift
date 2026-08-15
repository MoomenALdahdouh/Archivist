import Foundation

public struct DiskSpace: Sendable, Equatable {
    public var required: UInt64
    public var available: UInt64
    public var safetyMargin: UInt64

    public init(required: UInt64, available: UInt64, safetyMargin: UInt64) {
        self.required = required
        self.available = available
        self.safetyMargin = safetyMargin
    }

    public var shortage: UInt64 {
        let need = required.addingReportingOverflow(safetyMargin).partialValue
        return need > available ? need - available : 0
    }

    public var hasEnough: Bool { shortage == 0 }
}

public enum DiskSpaceChecker {
    public static func availableBytes(at url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            return UInt64(important)
        }
        if let available = values.volumeAvailableCapacity, available > 0 {
            return UInt64(available)
        }
        throw ArchiveError.io("Could not determine free disk space")
    }

    public static func evaluate(required: UInt64, destination: URL, marginRatio: Double = 0.05) throws -> DiskSpace {
        var writableDestination = destination
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
            writableDestination = destination.deletingLastPathComponent()
        }
        let available = try availableBytes(at: writableDestination)
        let margin = UInt64((Double(required) * marginRatio).rounded(.up))
        let space = DiskSpace(required: required, available: available, safetyMargin: max(margin, 1_048_576))
        if !space.hasEnough {
            throw ArchiveError.notEnoughDiskSpace(required: required + space.safetyMargin, available: available)
        }
        return space
    }

    public static func destinationIsWritable(_ url: URL) -> Bool {
        FileManager.default.isWritableFile(atPath: url.path)
    }
}
