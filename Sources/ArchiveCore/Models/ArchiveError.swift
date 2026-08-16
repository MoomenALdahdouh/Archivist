import Foundation

public enum ArchiveError: Error, Sendable, Equatable {
    case invalidArguments(String)
    case unsupportedFormat(ArchiveFormat)
    case formatNotCreatable(ArchiveFormat)
    case notAnArchive
    case incorrectPassword
    case corrupted(String)
    case unexpectedEnd
    case missingVolume(String)
    case unsupportedCompressionMethod(String)
    case notEnoughDiskSpace(required: UInt64, available: UInt64)
    case permissionDenied(String)
    case destinationNotWritable(String)
    case unsafePath(String)
    case fileExists(String)
    case io(String)
    case backendFailure(String)
    case cancelled
    case decompressionBomb(compressed: UInt64, uncompressed: UInt64)
    case safetyLimitExceeded(String)
    case helperMissing(String)
    case overwriteCancelled
    case interruptedJob(String)

    public var exitCode: Int32 {
        switch self {
        case .invalidArguments: 2
        case .corrupted, .unexpectedEnd: 3
        case .incorrectPassword: 4
        case .missingVolume: 5
        case .unsupportedFormat, .formatNotCreatable, .notAnArchive, .unsupportedCompressionMethod: 6
        case .permissionDenied, .destinationNotWritable: 7
        case .notEnoughDiskSpace: 8
        case .cancelled, .overwriteCancelled: 9
        default: 1
        }
    }

    public var errorCode: String {
        switch self {
        case .invalidArguments: "invalid_arguments"
        case .unsupportedFormat: "unsupported_format"
        case .formatNotCreatable: "format_not_creatable"
        case .notAnArchive: "not_an_archive"
        case .incorrectPassword: "incorrect_password"
        case .corrupted: "corrupted"
        case .unexpectedEnd: "unexpected_end"
        case .missingVolume: "missing_volume"
        case .unsupportedCompressionMethod: "unsupported_method"
        case .notEnoughDiskSpace: "disk_space"
        case .permissionDenied: "permission_denied"
        case .destinationNotWritable: "destination_not_writable"
        case .unsafePath: "unsafe_path"
        case .fileExists: "file_exists"
        case .io: "io_error"
        case .backendFailure: "backend_failure"
        case .cancelled: "cancelled"
        case .decompressionBomb: "decompression_bomb"
        case .safetyLimitExceeded: "safety_limit"
        case .helperMissing: "helper_missing"
        case .overwriteCancelled: "overwrite_cancelled"
        case .interruptedJob: "interrupted_job"
        }
    }

    public var userMessage: String {
        switch self {
        case .invalidArguments(let detail):
            return "Invalid arguments. \(detail)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format.displayName)."
        case .formatNotCreatable(let format):
            return "Archivist cannot create \(format.displayName) archives."
        case .notAnArchive:
            return "This file is not a recognized archive."
        case .incorrectPassword:
            return "Incorrect password."
        case .corrupted(let detail):
            return "Archive is corrupted. \(detail)"
        case .unexpectedEnd:
            return "Unexpected end of archive."
        case .missingVolume(let name):
            return "Missing volume: \(name)."
        case .unsupportedCompressionMethod(let method):
            return "Unsupported compression method: \(method)."
        case .notEnoughDiskSpace(let required, let available):
            let shortage = required > available ? required - available : 0
            return "Not enough free disk space.\nRequired: \(ByteCountFormat.string(from: required))\nAvailable: \(ByteCountFormat.string(from: available))\nShortage: \(ByteCountFormat.string(from: shortage))"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .destinationNotWritable(let path):
            return "Destination is not writable: \(path)"
        case .unsafePath(let path):
            return "Archive contains unsafe path: \(path)"
        case .fileExists(let path):
            return "File already exists: \(path)"
        case .io(let detail):
            return "I/O error. \(detail)"
        case .backendFailure(let detail):
            return "Archive backend failure. \(detail)"
        case .cancelled:
            return "The operation was cancelled."
        case .decompressionBomb(let compressed, let uncompressed):
            return "This archive expands dramatically.\nCompressed size: \(ByteCountFormat.string(from: compressed))\nEstimated output: \(ByteCountFormat.string(from: uncompressed))"
        case .safetyLimitExceeded(let detail):
            return "Safety limit exceeded. \(detail)"
        case .helperMissing(let name):
            return "Required helper is not installed: \(name)."
        case .overwriteCancelled:
            return "The operation was cancelled at an overwrite prompt."
        case .interruptedJob(let detail):
            return "An interrupted operation was detected. \(detail)"
        }
    }

    public var suggestedAction: String {
        switch self {
        case .incorrectPassword: "Check the password and try again."
        case .missingVolume: "Place all volume files in the same folder as the first volume."
        case .notEnoughDiskSpace: "Free disk space or choose another destination."
        case .permissionDenied, .destinationNotWritable: "Choose a folder you can write to, or check permissions."
        case .unsafePath: "Do not extract this archive unless you trust the source."
        case .helperMissing: "Run Scripts/build-helpers.sh so ArchivistRar and ArchivistUnrar are bundled."
        case .decompressionBomb: "Confirm you have enough disk space and that you trust this archive."
        case .unsupportedFormat, .formatNotCreatable: "Choose a supported format. See docs/SUPPORTED_FORMATS.md."
        default: "See technical details and diagnostics if the problem continues."
        }
    }

    public var technicalDetails: String {
        switch self {
        case .invalidArguments(let d),
             .corrupted(let d),
             .unsupportedCompressionMethod(let d),
             .permissionDenied(let d),
             .destinationNotWritable(let d),
             .unsafePath(let d),
             .fileExists(let d),
             .io(let d),
             .backendFailure(let d),
             .safetyLimitExceeded(let d),
             .helperMissing(let d),
             .interruptedJob(let d):
            return d
        case .unsupportedFormat(let f), .formatNotCreatable(let f):
            return f.rawValue
        case .notEnoughDiskSpace(let required, let available):
            return "required=\(required) available=\(available)"
        case .decompressionBomb(let compressed, let uncompressed):
            return "compressed=\(compressed) uncompressed=\(uncompressed)"
        case .missingVolume(let name):
            return name
        default:
            return errorCode
        }
    }

    /// Maps backend text to a typed error without including secrets.
    public static func fromBackendMessage(_ raw: String) -> ArchiveError {
        let message = Self.redact(raw)
        let lower = message.lowercased()
        if lower.contains("passphrase") || lower.contains("password") {
            return .incorrectPassword
        }
        if lower.contains("truncated") || lower.contains("unexpected end") || lower.contains("end of file") {
            return .unexpectedEnd
        }
        if lower.contains("crc") {
            return .corrupted("CRC mismatch")
        }
        if lower.contains("no space") || lower.contains("disk quota") {
            return .io(message)
        }
        if lower.contains("permission denied") {
            return .permissionDenied(message)
        }
        if lower.contains("encrypted") && lower.contains("not currently supported") {
            return .backendFailure("Encrypted entries require the 7-Zip or UnRAR helper.")
        }
        return .backendFailure(message)
    }

    public static func redact(_ text: String) -> String {
        var result = text
        let patterns = ["password=", "passphrase=", "--password", "-p"]
        for pattern in patterns {
            if let range = result.range(of: pattern, options: .caseInsensitive) {
                result.replaceSubrange(range.lowerBound..<result.endIndex, with: pattern + "<redacted>")
                break
            }
        }
        return result
    }
}

extension ArchiveError: LocalizedError {
    public var errorDescription: String? { userMessage }
    public var failureReason: String? { technicalDetails }
    public var recoverySuggestion: String? { suggestedAction }
}
