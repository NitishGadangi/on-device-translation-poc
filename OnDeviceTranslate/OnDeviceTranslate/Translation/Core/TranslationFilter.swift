import Foundation

/// A single skip heuristic. Returning `true` means "do not translate this string".
protocol SkipRule: Sendable {
    func skips(text: String, key: String?) -> Bool
}

/// A small, ordered rule engine that decides whether a JSON string leaf is worth
/// translating. Rules run cheapest-first and short-circuit on the first match, so
/// expensive checks (and language detection, which happens later) are avoided for
/// obvious non-content like URLs, IDs, and numbers.
struct TranslationFilter: Sendable {
    private let rules: [SkipRule]

    init(rules: [SkipRule] = TranslationFilter.defaultRules) {
        self.rules = rules
    }

    func shouldTranslate(_ text: String, key: String?) -> Bool {
        for rule in rules where rule.skips(text: text, key: key) { return false }
        return true
    }

    static let defaultRules: [SkipRule] = [
        EmptyOrWhitespaceRule(),
        KeyDenylistRule(),
        NoLettersRule(),
        URLRule(),
        FilePathRule(),
        UUIDOrLongHexRule(),
        SlugRule(),
        PureNumberRule(),
        ISODateRule()
    ]
}

/// Thread-safe precompiled regex wrapper (NSRegularExpression matching is safe to
/// share across threads).
struct CompiledRegex: @unchecked Sendable {
    private let regex: NSRegularExpression
    init(_ pattern: String) {
        regex = try! NSRegularExpression(pattern: pattern)
    }
    func matches(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, options: [.anchored], range: range) != nil
    }
}

private func trimmed(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct EmptyOrWhitespaceRule: SkipRule {
    func skips(text: String, key: String?) -> Bool {
        trimmed(text).isEmpty
    }
}

struct KeyDenylistRule: SkipRule {
    static let denylist: Set<String> = [
        "id", "uuid", "url", "href", "link", "image", "imageurl", "thumbnail",
        "avatar", "icon", "slug", "type", "code", "key", "token", "hash", "sku",
        "email", "phone", "locale", "lang", "language", "path", "filename"
    ]
    func skips(text: String, key: String?) -> Bool {
        guard let key else { return false }
        let normalized = key.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        return KeyDenylistRule.denylist.contains(normalized)
    }
}

/// No alphabetic characters at all (pure punctuation, numbers, or emoji).
struct NoLettersRule: SkipRule {
    func skips(text: String, key: String?) -> Bool {
        text.rangeOfCharacter(from: .letters) == nil
    }
}

struct URLRule: SkipRule {
    static let regex = CompiledRegex(#"([a-zA-Z][a-zA-Z0-9+.\-]*://|www\.)\S+"#)
    func skips(text: String, key: String?) -> Bool {
        URLRule.regex.matches(trimmed(text))
    }
}

struct FilePathRule: SkipRule {
    static let regex = CompiledRegex(#"(/|\./|\.\./|[A-Za-z]:\\)\S+"#)
    func skips(text: String, key: String?) -> Bool {
        FilePathRule.regex.matches(trimmed(text))
    }
}

struct UUIDOrLongHexRule: SkipRule {
    static let uuid = CompiledRegex(#"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#)
    static let longHex = CompiledRegex(#"[0-9a-fA-F]{16,}$"#)
    func skips(text: String, key: String?) -> Bool {
        let t = trimmed(text)
        return UUIDOrLongHexRule.uuid.matches(t) || UUIDOrLongHexRule.longHex.matches(t)
    }
}

/// Lowercase hyphen/underscore separated tokens with no spaces (e.g. "user-profile").
struct SlugRule: SkipRule {
    static let regex = CompiledRegex(#"[a-z0-9]+(?:[-_][a-z0-9]+)+$"#)
    func skips(text: String, key: String?) -> Bool {
        let t = trimmed(text)
        guard !t.contains(" ") else { return false }
        return SlugRule.regex.matches(t)
    }
}

struct PureNumberRule: SkipRule {
    static let regex = CompiledRegex(#"[+-]?\d+(?:[.,]\d+)*%?$"#)
    func skips(text: String, key: String?) -> Bool {
        PureNumberRule.regex.matches(trimmed(text))
    }
}

struct ISODateRule: SkipRule {
    static let regex = CompiledRegex(#"\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2})?(\.\d+)?(Z|[+-]\d{2}:?\d{2})?)?$"#)
    func skips(text: String, key: String?) -> Bool {
        ISODateRule.regex.matches(trimmed(text))
    }
}
