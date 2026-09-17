import Foundation

public struct SearchHit: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let snippet: String
    public let range: NSRange?
    public let line: Int?
}

public enum SearchEngine {
    public static func search(_ query: String, in drafts: [Draft]) -> [SearchHit] {
        guard !query.isEmpty else { return [] }
        return drafts.compactMap { draft in
            guard draft.metadata.deletedAt == nil else { return nil }
            let source = draft.text as NSString
            let match = source.range(of: query, options: .caseInsensitive)
            let titleMatches = draft.title.range(of: query, options: .caseInsensitive) != nil
            guard match.location != NSNotFound || titleMatches else { return nil }
            guard match.location != NSNotFound else {
                return SearchHit(id: draft.id, title: draft.title,
                                 snippet: String(draft.text.prefix(140)).replacingOccurrences(of: "\n", with: "  "),
                                 range: nil, line: nil)
            }
            let start = max(0, match.location - 45)
            let end = min(source.length, match.location + min(match.length, 150) + 85)
            let snippetRange = source.rangeOfComposedCharacterSequences(for: NSRange(location: start, length: end - start))
            let snippet = (start > 0 ? "…" : "") + source.substring(with: snippetRange)
                .replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: "  ") + (end < source.length ? "…" : "")
            let prefix = source.substring(to: match.location)
            let line = LineMap.starts(in: prefix).count
            return SearchHit(id: draft.id, title: draft.title, snippet: snippet, range: match, line: line)
        }
    }
}
