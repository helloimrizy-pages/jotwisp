import Foundation

public enum TokenKind: Sendable { case keyword, string, comment, number, heading, tag }
public struct SyntaxToken: Sendable {
    public let range: NSRange
    public let kind: TokenKind
}

public enum Highlighter {
    public static let limit = 1_000_000

    public static func tokens(in text: String, language: Language) -> [SyntaxToken] {
        guard language != .plain, text.utf8.count <= limit else { return [] }
        var rules: [(String, TokenKind)] = []
        switch language {
        case .plain: return []
        case .markdown:
            rules = [("(?m)^#{1,6} .*$", .heading), ("\\*\\*[^\\n]+?\\*\\*", .keyword),
                     ("\\[[^\\]\\n]+\\]\\([^\\)\\n]+\\)", .tag), ("`[^`\\n]*`", .string),
                     ("(?ms)^```.*?^```[^\\n]*", .comment)]
        case .html:
            rules = [("</?[A-Za-z][^>]*>", .tag), ("\"[^\"]*\"|'[^']*'", .string), ("(?s)<!--.*?-->", .comment)]
        case .css:
            rules = [("[.#]?[A-Za-z_-][A-Za-z0-9_-]*(?=\\s*\\{)", .heading),
                     ("[A-Za-z-]+(?=\\s*:)", .keyword), ("#[0-9a-fA-F]{3,8}\\b|\\b[0-9]+(?:px|em|rem|%)?", .number),
                     ("\"[^\"]*\"|'[^']*'", .string), ("(?s)/\\*.*?\\*/", .comment)]
        default:
            let keywords: String
            switch language {
            case .json: keywords = "true|false|null"
            case .python: keywords = "def|class|return|if|elif|else|for|while|in|import|from|as|try|except|finally|raise|with|yield|lambda|pass|break|continue|and|or|not|is|None|True|False|async|await|self"
            case .swift: keywords = "let|var|func|class|struct|enum|protocol|extension|import|return|if|else|guard|for|while|in|switch|case|default|break|continue|throw|throws|try|catch|do|public|private|internal|static|init|self|Self|nil|true|false|async|await|actor|some|any|override|weak"
            case .shell: keywords = "if|then|else|elif|fi|for|while|do|done|in|case|esac|function|export|local|return|echo|exit|source"
            default: keywords = "const|let|var|function|return|if|else|for|while|of|in|class|new|this|import|export|from|default|async|await|try|catch|throw|switch|case|break|continue|true|false|null|undefined|interface|type|extends|implements|public|private|readonly|enum|typeof|instanceof"
            }
            rules = [("\\b(?:" + keywords + ")\\b", .keyword),
                     ("\\b[0-9]+(?:\\.[0-9]+)?\\b", .number),
                     ("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`", .string)]
            if language == .python || language == .shell {
                rules.append(("(?m)#.*$", .comment))
            } else if language != .json {
                rules.append(("(?m)//.*$|(?s:/\\*.*?\\*/)", .comment))
            }
        }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        var tokens: [SyntaxToken] = []
        for (pattern, kind) in rules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: fullRange) {
                tokens.append(SyntaxToken(range: match.range, kind: kind))
            }
        }
        return tokens
    }
}
