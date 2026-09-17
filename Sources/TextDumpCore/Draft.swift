import Foundation

public enum Language: String, Codable, CaseIterable, Sendable {
    case plain = "Plain Text", markdown = "Markdown", json = "JSON"
    case javascript = "JavaScript", typescript = "TypeScript", python = "Python"
    case swift = "Swift", html = "HTML", css = "CSS", shell = "Shell"

    public static func infer(extension ext: String) -> Language {
        switch ext.lowercased() {
        case "md", "markdown": return .markdown
        case "json", "jsonl": return .json
        case "js", "jsx", "mjs", "cjs": return .javascript
        case "ts", "tsx": return .typescript
        case "py", "pyw": return .python
        case "swift": return .swift
        case "html", "htm", "xml", "svg": return .html
        case "css", "scss": return .css
        case "sh", "bash", "zsh": return .shell
        default: return .plain
        }
    }

    public var fileExtension: String {
        switch self {
        case .plain: return "txt"
        case .markdown: return "md"
        case .json: return "json"
        case .javascript: return "js"
        case .typescript: return "ts"
        case .python: return "py"
        case .swift: return "swift"
        case .html: return "html"
        case .css: return "css"
        case .shell: return "sh"
        }
    }
}

public struct Draft: Identifiable, Sendable {
    public var metadata: DraftMetadata
    public var text: String
    public var id: UUID { metadata.id }
    public var title: String { metadata.customTitle ?? Self.automaticTitle(text) }

    public init(id: UUID = UUID(), text: String = "", title: String? = nil,
                language: Language = .plain, createdAt: Date = Date()) {
        metadata = DraftMetadata(id: id, customTitle: title, createdAt: createdAt,
                                 modifiedAt: createdAt, language: language)
        self.text = text
    }

    public init(metadata: DraftMetadata, text: String) {
        self.metadata = metadata
        self.text = text
    }

    public static func automaticTitle(_ text: String) -> String {
        // A bounded prefix keeps typing into very large drafts inexpensive.
        for line in text.prefix(4096).split(whereSeparator: \.isNewline) {
            let title = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return String(title.prefix(72)) }
        }
        return "Untitled"
    }
}

public struct DraftMetadata: Codable, Sendable {
    public var version = 1
    public var id: UUID
    public var customTitle: String?
    public var createdAt: Date
    public var modifiedAt: Date
    public var language: Language = .plain
    public var wraps = true
    // Missing on older drafts, which used non-wrapping text as their default.
    public var wrapPreferenceVersion: Int? = 1
    public var deletedAt: Date?
    public var cursor = 0
    public var selectionLength = 0
    public var scrollX: Double = 0
    public var scrollY: Double = 0
}

public struct Session: Codable, Sendable {
    public var version = 1
    public var selectedID: UUID?
    public var sidebarWidth: Double = 256
    public init(selectedID: UUID? = nil, sidebarWidth: Double = 256) {
        self.selectedID = selectedID
        self.sidebarWidth = sidebarWidth
    }
}
