import Foundation
import CryptoKit

public enum ContentHash {
    public static func sha256File(at url: URL, bufferSize: Int = 1024 * 1024) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: bufferSize) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct FileTreeWalker: Sendable {
    public var followSymlinks: Bool
    public var skipHiddenAppleDouble: Bool

    public init(followSymlinks: Bool = false, skipHiddenAppleDouble: Bool = true) {
        self.followSymlinks = followSymlinks
        self.skipHiddenAppleDouble = skipHiddenAppleDouble
    }

    public struct Item: Sendable {
        public var url: URL
        public var relativePath: String
        public var isDirectory: Bool
        public var isSymlink: Bool
        public var size: UInt64
    }

    public func walk(_ sources: [URL]) throws -> [Item] {
        var items: [Item] = []
        let fm = FileManager.default
        for source in sources {
            let root = source.standardizedFileURL
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else {
                throw ArchiveError.io("Source does not exist: \(root.path)")
            }
            let rootName = root.lastPathComponent
            if isDir.boolValue {
                items.append(Item(url: root, relativePath: rootName, isDirectory: true, isSymlink: false, size: 0))
                let enumerator = fm.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
                    options: followSymlinks ? [] : [.skipsPackageDescendants]
                )
                while let item = enumerator?.nextObject() as? URL {
                    if skipHiddenAppleDouble, item.lastPathComponent.hasPrefix("._") {
                        continue
                    }
                    let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
                    let rel = relativePath(of: item, to: root.deletingLastPathComponent())
                    let symlink = values.isSymbolicLink ?? false
                    let dir = values.isDirectory ?? false
                    let size = UInt64(values.fileSize ?? 0)
                    items.append(Item(url: item, relativePath: rel, isDirectory: dir && !symlink, isSymlink: symlink, size: size))
                }
            } else {
                let values = try root.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
                items.append(
                    Item(
                        url: root,
                        relativePath: rootName,
                        isDirectory: false,
                        isSymlink: values.isSymbolicLink ?? false,
                        size: UInt64(values.fileSize ?? 0)
                    )
                )
            }
        }
        return items
    }

    public func totalBytes(_ items: [Item]) -> UInt64 {
        items.reduce(into: 0) { $0 += $1.size }
    }

    private func relativePath(of url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(rootPath) {
            var rel = String(path.dropFirst(rootPath.count))
            if rel.hasPrefix("/") { rel.removeFirst() }
            return rel
        }
        return url.lastPathComponent
    }
}
