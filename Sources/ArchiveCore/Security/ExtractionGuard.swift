import Foundation

public enum PathNormalizer {
    /// Normalizes an archive entry path into a relative POSIX path using `/` separators.
    public static func normalize(_ raw: String) -> Result<String, ArchiveError> {
        if raw.isEmpty {
            return .failure(.unsafePath("(empty)"))
        }
        if raw.contains("\0") {
            return .failure(.unsafePath("null byte in filename"))
        }
        var path = raw.replacingOccurrences(of: "\\", with: "/")
        path = path.replacingOccurrences(of: "\r", with: "")
        path = path.replacingOccurrences(of: "\n", with: "")

        if path.hasPrefix("~") {
            return .failure(.unsafePath(raw))
        }

        // Reject Windows drive-letter and UNC-style absolute paths.
        if path.count >= 2, path[path.index(path.startIndex, offsetBy: 1)] == ":",
           path[path.startIndex].isLetter {
            return .failure(.unsafePath(raw))
        }
        if path.hasPrefix("//") || path.hasPrefix("\\\\") {
            return .failure(.unsafePath(raw))
        }

        if path.hasPrefix("/") {
            return .failure(.unsafePath(raw))
        }

        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var stack: [String] = []
        for part in parts {
            if part.isEmpty || part == "." {
                continue
            }
            if part == ".." {
                return .failure(.unsafePath(raw))
            }
            if part == "." || part == ".." {
                return .failure(.unsafePath(raw))
            }
            stack.append(part)
        }

        if stack.isEmpty {
            return .success("")
        }

        let normalized = stack.joined(separator: "/")
        return .success(normalized)
    }

    public static func unicodeSafe(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping
    }
}

public struct ExtractionGuard: Sendable {
    public var limits: SafetyLimits

    public init(limits: SafetyLimits = .default) {
        self.limits = limits
    }

    public func validatedRelativePath(_ raw: String) throws -> String {
        switch PathNormalizer.normalize(raw) {
        case .failure(let error):
            throw error
        case .success(let relative):
            if relative.utf8.count > limits.maximumPathLength {
                throw ArchiveError.safetyLimitExceeded("Path exceeds maximum length")
            }
            let depth = relative.split(separator: "/").count
            if depth > limits.maximumNestingDepth {
                throw ArchiveError.safetyLimitExceeded("Path exceeds maximum nesting depth")
            }
            return PathNormalizer.unicodeSafe(relative)
        }
    }

    public func resolvedURL(entryPath: String, destination: URL) throws -> URL {
        let relative = try validatedRelativePath(entryPath)
        let dest = destination.standardizedFileURL
        if relative.isEmpty {
            return dest
        }
        var url = dest
        for component in relative.split(separator: "/") {
            url.appendPathComponent(String(component), isDirectory: false)
        }
        let standardized = url.standardizedFileURL
        let destPath = dest.path.hasSuffix("/") ? dest.path : dest.path + "/"
        let outPath = standardized.path
        if outPath != dest.path && !outPath.hasPrefix(destPath) {
            throw ArchiveError.unsafePath(entryPath)
        }
        return standardized
    }

    public func validateSymlinkTarget(_ target: String, linkURL: URL, destination: URL) throws {
        if target.contains("\0") {
            throw ArchiveError.unsafePath(target)
        }
        if target.hasPrefix("/") || target.hasPrefix("~") {
            throw ArchiveError.unsafePath(target)
        }
        let resolved: URL
        if target.hasPrefix("/") {
            throw ArchiveError.unsafePath(target)
        }
        resolved = URL(fileURLWithPath: target, relativeTo: linkURL.deletingLastPathComponent()).standardizedFileURL
        let dest = destination.standardizedFileURL
        let destPath = dest.path.hasSuffix("/") ? dest.path : dest.path + "/"
        if resolved.path != dest.path && !resolved.path.hasPrefix(destPath) {
            throw ArchiveError.unsafePath(target)
        }
        _ = try validatedRelativePath(target.replacingOccurrences(of: "\\", with: "/"))
    }

    public func checkBomb(compressed: UInt64, uncompressed: UInt64) throws {
        guard uncompressed >= limits.bombMinimumUncompressedBytes, compressed > 0 else { return }
        let ratio = Double(uncompressed) / Double(compressed)
        if ratio >= limits.bombRatio {
            throw ArchiveError.decompressionBomb(compressed: compressed, uncompressed: uncompressed)
        }
    }

    public func checkCounts(files: UInt64, bytes: UInt64) throws {
        if files > limits.maximumFileCount {
            throw ArchiveError.safetyLimitExceeded("Maximum number of files exceeded")
        }
        if bytes > limits.maximumExtractedBytes {
            throw ArchiveError.safetyLimitExceeded("Maximum extracted size exceeded")
        }
    }
}
