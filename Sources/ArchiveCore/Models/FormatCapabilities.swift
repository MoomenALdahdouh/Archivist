import Foundation

public struct FormatCapabilities: Sendable, Hashable, Codable {
    public var list: Bool
    public var extract: Bool
    public var create: Bool
    public var test: Bool
    public var password: Bool
    public var encryptFilenames: Bool
    public var split: Bool
    public var modify: Bool
    public var notes: String

    public init(
        list: Bool = false,
        extract: Bool = false,
        create: Bool = false,
        test: Bool = false,
        password: Bool = false,
        encryptFilenames: Bool = false,
        split: Bool = false,
        modify: Bool = false,
        notes: String = ""
    ) {
        self.list = list
        self.extract = extract
        self.create = create
        self.test = test
        self.password = password
        self.encryptFilenames = encryptFilenames
        self.split = split
        self.modify = modify
        self.notes = notes
    }

    public static let unsupported = FormatCapabilities(notes: "Unsupported")
}

public enum BackendKind: String, Sendable, Codable {
    case libarchive
    case sevenZipHelper
    case unrarHelper
    case filter
    case diskImage
    case none
}
