import Foundation

/// A recursive JSON representation that preserves object key order and numeric
/// precision (numbers are kept as their raw lexical token). This lets the
/// translator rewrite only string leaf-values and re-emit byte-faithful JSON, so
/// the schema can never break during translation.
indirect enum JSONValue: Equatable {
    case string(String)
    case number(String)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([Member])

    struct Member: Equatable {
        let key: String
        var value: JSONValue
    }
}

// MARK: - String collection & rewriting

extension JSONValue {
    struct StringLeaf {
        let path: String
        let key: String?
        let text: String
    }

    func collectStrings(path: String = "$", key: String? = nil, into leaves: inout [StringLeaf]) {
        switch self {
        case .string(let s):
            leaves.append(StringLeaf(path: path, key: key, text: s))
        case .array(let elements):
            for (i, element) in elements.enumerated() {
                element.collectStrings(path: "\(path)[\(i)]", key: nil, into: &leaves)
            }
        case .object(let members):
            for member in members {
                member.value.collectStrings(path: "\(path).\(member.key)", key: member.key, into: &leaves)
            }
        case .number, .bool, .null:
            break
        }
    }

    /// Returns a copy with every string leaf replaced by `map[value]` when present.
    /// Missing entries keep the original, so partial/failed translation is safe.
    func replacingStrings(_ map: [String: String]) -> JSONValue {
        switch self {
        case .string(let s):
            return .string(map[s] ?? s)
        case .array(let elements):
            return .array(elements.map { $0.replacingStrings(map) })
        case .object(let members):
            return .object(members.map { Member(key: $0.key, value: $0.value.replacingStrings(map)) })
        case .number, .bool, .null:
            return self
        }
    }
}

// MARK: - Encoding

extension JSONValue {
    func encode() -> Data {
        var out: [UInt8] = []
        write(into: &out)
        return Data(out)
    }

    private func write(into out: inout [UInt8]) {
        switch self {
        case .null:
            out.append(contentsOf: Array("null".utf8))
        case .bool(let b):
            out.append(contentsOf: Array((b ? "true" : "false").utf8))
        case .number(let token):
            out.append(contentsOf: Array(token.utf8))
        case .string(let s):
            JSONValue.writeString(s, into: &out)
        case .array(let elements):
            out.append(0x5B)
            for (i, element) in elements.enumerated() {
                if i > 0 { out.append(0x2C) }
                element.write(into: &out)
            }
            out.append(0x5D)
        case .object(let members):
            out.append(0x7B)
            for (i, member) in members.enumerated() {
                if i > 0 { out.append(0x2C) }
                JSONValue.writeString(member.key, into: &out)
                out.append(0x3A)
                member.value.write(into: &out)
            }
            out.append(0x7D)
        }
    }

    private static func writeString(_ s: String, into out: inout [UInt8]) {
        out.append(0x22)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out.append(contentsOf: Array("\\\"".utf8))
            case "\\": out.append(contentsOf: Array("\\\\".utf8))
            case "\n": out.append(contentsOf: Array("\\n".utf8))
            case "\r": out.append(contentsOf: Array("\\r".utf8))
            case "\t": out.append(contentsOf: Array("\\t".utf8))
            case "\u{08}": out.append(contentsOf: Array("\\b".utf8))
            case "\u{0C}": out.append(contentsOf: Array("\\f".utf8))
            default:
                if scalar.value < 0x20 {
                    out.append(contentsOf: Array(String(format: "\\u%04x", scalar.value).utf8))
                } else {
                    out.append(contentsOf: Array(String(scalar).utf8))
                }
            }
        }
        out.append(0x22)
    }
}

// MARK: - Parsing

enum JSONParseError: Error {
    case unexpectedEnd
    case unexpected(at: Int)
    case depthExceeded
    case trailingData(at: Int)
}

struct JSONParser {
    private let bytes: [UInt8]
    private var index = 0
    private let maxDepth: Int

    private init(_ data: Data, maxDepth: Int) {
        self.bytes = [UInt8](data)
        self.maxDepth = maxDepth
    }

    static func parse(_ data: Data, maxDepth: Int = 512) throws -> JSONValue {
        var parser = JSONParser(data, maxDepth: maxDepth)
        let value = try parser.parseValue(depth: 0)
        parser.skipWhitespace()
        guard parser.index == parser.bytes.count else {
            throw JSONParseError.trailingData(at: parser.index)
        }
        return value
    }

    private func peek() -> UInt8? { index < bytes.count ? bytes[index] : nil }

    private mutating func skipWhitespace() {
        while let b = peek(), b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D { index += 1 }
    }

    private mutating func parseValue(depth: Int) throws -> JSONValue {
        guard depth <= maxDepth else { throw JSONParseError.depthExceeded }
        skipWhitespace()
        guard let b = peek() else { throw JSONParseError.unexpectedEnd }
        switch b {
        case 0x7B: return try parseObject(depth: depth)
        case 0x5B: return try parseArray(depth: depth)
        case 0x22: return .string(try parseString())
        case 0x74, 0x66: return try parseBool()
        case 0x6E: try parseNull(); return .null
        case 0x2D, 0x30...0x39: return .number(try parseNumberToken())
        default: throw JSONParseError.unexpected(at: index)
        }
    }

    private mutating func parseObject(depth: Int) throws -> JSONValue {
        index += 1
        var members: [JSONValue.Member] = []
        skipWhitespace()
        if peek() == 0x7D { index += 1; return .object(members) }
        while true {
            skipWhitespace()
            guard peek() == 0x22 else { throw JSONParseError.unexpected(at: index) }
            let key = try parseString()
            skipWhitespace()
            guard peek() == 0x3A else { throw JSONParseError.unexpected(at: index) }
            index += 1
            let value = try parseValue(depth: depth + 1)
            members.append(JSONValue.Member(key: key, value: value))
            skipWhitespace()
            switch peek() {
            case 0x2C: index += 1
            case 0x7D: index += 1; return .object(members)
            default: throw JSONParseError.unexpected(at: index)
            }
        }
    }

    private mutating func parseArray(depth: Int) throws -> JSONValue {
        index += 1
        var elements: [JSONValue] = []
        skipWhitespace()
        if peek() == 0x5D { index += 1; return .array(elements) }
        while true {
            let value = try parseValue(depth: depth + 1)
            elements.append(value)
            skipWhitespace()
            switch peek() {
            case 0x2C: index += 1
            case 0x5D: index += 1; return .array(elements)
            default: throw JSONParseError.unexpected(at: index)
            }
        }
    }

    private mutating func parseString() throws -> String {
        index += 1
        var utf8: [UInt8] = []
        while index < bytes.count {
            let b = bytes[index]; index += 1
            switch b {
            case 0x22:
                return String(decoding: utf8, as: UTF8.self)
            case 0x5C:
                guard index < bytes.count else { throw JSONParseError.unexpectedEnd }
                let esc = bytes[index]; index += 1
                switch esc {
                case 0x22: utf8.append(0x22)
                case 0x5C: utf8.append(0x5C)
                case 0x2F: utf8.append(0x2F)
                case 0x62: utf8.append(0x08)
                case 0x66: utf8.append(0x0C)
                case 0x6E: utf8.append(0x0A)
                case 0x72: utf8.append(0x0D)
                case 0x74: utf8.append(0x09)
                case 0x75: try appendUnicodeEscape(into: &utf8)
                default: throw JSONParseError.unexpected(at: index)
                }
            default:
                utf8.append(b)
            }
        }
        throw JSONParseError.unexpectedEnd
    }

    private mutating func appendUnicodeEscape(into utf8: inout [UInt8]) throws {
        let unit = try readHex4()
        if unit >= 0xD800 && unit <= 0xDBFF {
            guard index + 1 < bytes.count, bytes[index] == 0x5C, bytes[index + 1] == 0x75 else {
                throw JSONParseError.unexpected(at: index)
            }
            index += 2
            let low = try readHex4()
            guard low >= 0xDC00 && low <= 0xDFFF else { throw JSONParseError.unexpected(at: index) }
            let codepoint = 0x10000 + (UInt32(unit - 0xD800) << 10) + UInt32(low - 0xDC00)
            if let scalar = Unicode.Scalar(codepoint) {
                utf8.append(contentsOf: Array(String(scalar).utf8))
            }
        } else if let scalar = Unicode.Scalar(UInt32(unit)) {
            utf8.append(contentsOf: Array(String(scalar).utf8))
        }
    }

    private mutating func readHex4() throws -> UInt16 {
        guard index + 4 <= bytes.count else { throw JSONParseError.unexpectedEnd }
        var value: UInt16 = 0
        for _ in 0..<4 {
            let b = bytes[index]; index += 1
            value <<= 4
            switch b {
            case 0x30...0x39: value += UInt16(b - 0x30)
            case 0x41...0x46: value += UInt16(b - 0x41 + 10)
            case 0x61...0x66: value += UInt16(b - 0x61 + 10)
            default: throw JSONParseError.unexpected(at: index)
            }
        }
        return value
    }

    private mutating func parseNumberToken() throws -> String {
        let start = index
        if peek() == 0x2D { index += 1 }
        while let b = peek(),
              (b >= 0x30 && b <= 0x39) || b == 0x2E || b == 0x65 || b == 0x45 || b == 0x2B || b == 0x2D {
            index += 1
        }
        guard index > start else { throw JSONParseError.unexpected(at: start) }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    private mutating func parseBool() throws -> JSONValue {
        if matchLiteral("true") { return .bool(true) }
        if matchLiteral("false") { return .bool(false) }
        throw JSONParseError.unexpected(at: index)
    }

    private mutating func parseNull() throws {
        guard matchLiteral("null") else { throw JSONParseError.unexpected(at: index) }
    }

    private mutating func matchLiteral(_ literal: String) -> Bool {
        let lit = Array(literal.utf8)
        guard index + lit.count <= bytes.count else { return false }
        for i in 0..<lit.count where bytes[index + i] != lit[i] { return false }
        index += lit.count
        return true
    }
}
