import Foundation

public actor TempDirectoryManager {
    public static let shared = TempDirectoryManager()

    private let log = ArchiveLogger(category: .filesystem)
    private let root: URL
    private let fm = FileManager.default

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.root = base.appendingPathComponent("Archivist", isDirectory: true)
        }
    }

    public var rootURL: URL { root }

    public func prepareRoot() throws {
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try (root as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: root.path
        )
    }

    public func makeJobDirectory(id: UUID) throws -> URL {
        try prepareRoot()
        let dir = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let marker = dir.appendingPathComponent(".archivist-job.json")
        let payload = """
        {"id":"\(id.uuidString)","created":\(Date().timeIntervalSince1970),"pid":\(ProcessInfo.processInfo.processIdentifier)}
        """
        try Data(payload.utf8).write(to: marker, options: .atomic)
        return dir
    }

    public func removeJobDirectory(id: UUID) {
        let dir = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try? fm.removeItem(at: dir)
    }

    public func interruptedJobs() throws -> [URL] {
        try prepareRoot()
        let contents = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return contents.filter { url in
            fm.fileExists(atPath: url.appendingPathComponent(".archivist-job.json").path)
        }
    }

    public func cleanupInterrupted() throws {
        for job in try interruptedJobs() {
            log.info("Removing leftover temporary job directory \(job.lastPathComponent)")
            try? fm.removeItem(at: job)
        }
    }
}

public enum AtomicFile {
    public static func replace(original: URL, withTemporary temporary: URL) throws {
        let fm = FileManager.default
        let parent = original.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        if fm.fileExists(atPath: original.path) {
            _ = try fm.replaceItemAt(original, withItemAt: temporary)
        } else {
            try fm.moveItem(at: temporary, to: original)
        }
    }

    public static func uniqueTemporaryURL(in directory: URL, name: String) -> URL {
        directory.appendingPathComponent(".\(name).\(UUID().uuidString).partial")
    }
}
