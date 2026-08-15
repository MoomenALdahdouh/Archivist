import Foundation

public struct SearchQuery: Sendable, Equatable {
    public var text: String
    public var caseSensitive: Bool
    public var useRegex: Bool

    public init(text: String, caseSensitive: Bool = false, useRegex: Bool = false) {
        self.text = text
        self.caseSensitive = caseSensitive
        self.useRegex = useRegex
    }
}

public enum ArchiveSearch {
    public static func matches(_ entry: ArchiveEntry, query: SearchQuery) -> Bool {
        let raw = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return true }
        let haystacks = [entry.path, entry.name, (entry.path as NSString).pathExtension]
        if query.useRegex {
            let options: NSRegularExpression.Options = query.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: raw, options: options) else { return false }
            return haystacks.contains { hay in
                regex.firstMatch(in: hay, range: NSRange(hay.startIndex..., in: hay)) != nil
            }
        }
        if raw.contains("*") || raw.contains("?") {
            let pattern = globToRegex(raw)
            let options: NSRegularExpression.Options = query.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
            return haystacks.contains { hay in
                regex.firstMatch(in: hay, range: NSRange(hay.startIndex..., in: hay)) != nil
            }
        }
        if query.caseSensitive {
            return haystacks.contains { $0.contains(raw) }
        }
        let needle = raw.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return haystacks.contains {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle)
        }
    }

    public static func filter(_ entries: [ArchiveEntry], query: SearchQuery) -> [ArchiveEntry] {
        entries.filter { matches($0, query: query) }
    }

    static func globToRegex(_ glob: String) -> String {
        var result = "^"
        for ch in glob {
            switch ch {
            case "*": result += ".*"
            case "?": result += "."
            case ".", "[", "]", "(", ")", "{", "}", "+", "^", "$", "|", "\\":
                result += "\\\(ch)"
            default:
                result.append(ch)
            }
        }
        result += "$"
        return result
    }
}
