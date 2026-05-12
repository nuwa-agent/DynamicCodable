//
//  TOMLParser.swift
//  Nuwa
//

import Foundation
import DynamicCodable

public struct TOMLParser {

    private var tomlString: String = ""
    private var lineIndex: Int = 0
    private var lines: [String] = []
    private var pendingComments: [String] = []
    // 当前正在填充的表路径（"" 表示根表）
    private var currentTablePath: [String] = []
    // 根节点，所有修改直接通过 key path 操作 root
    private var root: Node = Node(.object(OrderedDictionary<String, Node>()))
    // 已遇到过的表路径，用于检测重复
    private var seenTablePaths: Set<String> = [""]
    // 内联表正在解析标志
    private var inInlineTable: Bool = false
    // 当前表是否为数组表（键值对需写入最后一个数组元素）
    private var inArrayTable: Bool = false

    public init() {}

    public mutating func parse(_ toml: String) throws -> Node {
        self.tomlString = toml
        self.lines = toml.components(separatedBy: .newlines)
        self.lineIndex = 0
        self.pendingComments = []
        self.currentTablePath = []
        self.root = Node(.object(OrderedDictionary<String, Node>()))
        self.seenTablePaths = [""]
        while lineIndex < lines.count {
            try parseLine()
        }
        if !pendingComments.isEmpty {
            root.comments = pendingComments
            pendingComments.removeAll()
        }
        return root
    }

    private mutating func parseLine() throws {
        let rawLine = lines[lineIndex]
        lineIndex += 1
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return }
        // 注释行累积
        if trimmed.hasPrefix("#") {
            pendingComments.append(extractComment(trimmed))
            return
        }
        // 表头 [table] 或 [[array-of-tables]]
        if trimmed.hasPrefix("[") {
            try parseTableHeader(trimmed)
            return
        }
        // 键值对
        try parseKeyValue(trimmed)
    }

    // MARK: - 表头解析

    private mutating func parseTableHeader(_ line: String) throws {
        let isArrayTable = line.hasPrefix("[[") && line.hasSuffix("]]")
        let comments = pendingComments
        pendingComments.removeAll()
        // 重置数组表状态
        inArrayTable = false

        if isArrayTable {
            let inner = String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
            let path = try parseTableKeyPath(inner, line: lineIndex - 1)
            currentTablePath = path
            inArrayTable = true
            let tableName = path.last!
            let parentPath = Array(path.dropLast())
            // 从 root 获取数组
            var arrayNode = nodeAtPath(parentPath, in: root)[tableName]
            if arrayNode.rawValue == .null {
                arrayNode = Node(.array([]))
            } else if !arrayNode.isArray {
                throw TOMLError.syntaxError("表数组键 \(tableName) 已被定义为非数组类型", line: lineIndex - 1)
            }
            guard case .array(var items) = arrayNode.rawValue else {
                throw TOMLError.syntaxError("表数组键 \(tableName) 已被定义为非数组类型", line: lineIndex - 1)
            }
            var newTable = Node(.object(OrderedDictionary<String, Node>()))
            newTable.comments = comments
            items.append(newTable)
            arrayNode = Node(.array(items))
            // 写回 root
            root = setNodeAtPath(parentPath + [tableName], in: root, to: arrayNode, createIntermediates: true)
        } else {
            let inner = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            let path = try parseTableKeyPath(inner, line: lineIndex - 1)
            currentTablePath = path
            let tableKey = path.joined(separator: ".")
            if seenTablePaths.contains(tableKey) {
                throw TOMLError.duplicateTable("重复的表定义: [\(tableKey)]", line: lineIndex - 1)
            }
            seenTablePaths.insert(tableKey)
            // 确保路径存在，并获取/创建节点
            let tableNode: Node
            let existing = nodeAtPath(path, in: root)
            if existing.isNull || existing.rawValue == .null {
                tableNode = Node(.object(OrderedDictionary<String, Node>()))
            } else {
                tableNode = existing
            }
            if !comments.isEmpty {
                var mutableNode = tableNode
                mutableNode.comments = comments
                root = setNodeAtPath(path, in: root, to: mutableNode, createIntermediates: true)
            } else {
                root = setNodeAtPath(path, in: root, to: tableNode, createIntermediates: true)
            }
        }
    }

    // MARK: - 键值对解析

    private mutating func parseKeyValue(_ line: String) throws {
        let (content, inlineComment) = splitInlineComment(line)
        let (keys, valueStr) = try splitKeyValue(String(content).trimmingCharacters(in: .whitespaces), lineIndex: lineIndex - 1)

        var value = try parseValue(String(valueStr).trimmingCharacters(in: .whitespaces), line: lineIndex - 1)
        value.inlineComment = inlineComment

        if !pendingComments.isEmpty {
            value.comments = pendingComments
            pendingComments.removeAll()
        }

        // 确定写入路径
        let fullPath: [String]
        if currentTablePath.isEmpty {
            fullPath = keys
        } else if inArrayTable {
            // 数组表：定位到当前表数组的最后一个元素
            // 例如 [[products]] 后的 key = value →
            // root["products"][lastIndex]["key"] = value
            let arrayNode = nodeAtPath(currentTablePath, in: root)
            if case .array(let items) = arrayNode.rawValue, !items.isEmpty {
                let lastIdx = items.count - 1
                fullPath = currentTablePath + ["\(lastIdx)"] + keys
            } else {
                fullPath = currentTablePath + keys
            }
        } else {
            fullPath = currentTablePath + keys
        }

        // 单键检查重复（数组表和内联表内不检查，内联表允许后值覆盖前值）
        if !inArrayTable && !inInlineTable && keys.count == 1 {
            let existing = nodeAtPath(fullPath, in: root)
            if existing.rawValue != .null {
                throw TOMLError.duplicateKey("重复的键: \(keys[0])", line: lineIndex - 1)
            }
        }
        // 通过 root 设置值（值类型安全操作）
        root = setNodeAtPath(fullPath, in: root, to: value, createIntermediates: true)
    }

    // MARK: - 值解析

    private mutating func parseValue(_ str: String, line: Int) throws -> Node {
        if str.isEmpty {
            throw TOMLError.syntaxError("值不能为空", line: line)
        }
        if str.hasPrefix("[") && !str.hasPrefix("[[") {
            return try parseArray(str, line: line)
        }
        if str.hasPrefix("{") {
            return try parseInlineTable(str, line: line)
        }
        if str == "true" || str == "false" {
            return Node(.bool(str == "true"))
        }
        if str.hasPrefix("\"\"\"") {
            return try parseBasicMultiLineString(str, line: line)
        }
        if str.hasPrefix("'''") {
            return try parseLiteralMultiLineString(str, line: line)
        }
        if str.hasPrefix("\"") {
            return try parseBasicString(str, line: line)
        }
        if str.hasPrefix("'") {
            return try parseLiteralString(str, line: line)
        }
        if let node = tryParseDateTime(str) {
            return node
        }
        if let node = tryParseNumber(str) {
            return node
        }
        throw TOMLError.syntaxError("无法识别的值: \(str)", line: line)
    }

    // MARK: - 字符串解析

    private func parseBasicString(_ str: String, line: Int) throws -> Node {
        var s = str
        if s.hasPrefix("\"") { s = String(s.dropFirst()) }
        if s.hasSuffix("\"") { s = String(s.dropLast()) }
        let unescaped = try unescapeBasicString(s, line: line)
        return Node(.string(unescaped))
    }

    private func parseLiteralString(_ str: String, line: Int) throws -> Node {
        var s = str
        if s.hasPrefix("'") { s = String(s.dropFirst()) }
        if s.hasSuffix("'") { s = String(s.dropLast()) }
        return Node(.string(s))
    }

    private func parseBasicMultiLineString(_ str: String, line: Int) throws -> Node {
        var s = str
        if s.hasPrefix("\"\"\"") { s = String(s.dropFirst(3)) }
        if s.hasSuffix("\"\"\"") { s = String(s.dropLast(3)) }
        if s.hasPrefix("\n") {
            s = String(s.dropFirst())
        }
        let unescaped = try unescapeBasicString(s, line: line)
        return Node(.string(unescaped))
    }

    private func parseLiteralMultiLineString(_ str: String, line: Int) throws -> Node {
        var s = str
        if s.hasPrefix("'''") { s = String(s.dropFirst(3)) }
        if s.hasSuffix("'''") { s = String(s.dropLast(3)) }
        if s.hasPrefix("\n") {
            s = String(s.dropFirst())
        }
        return Node(.string(s))
    }

    private func unescapeBasicString(_ s: String, line: Int) throws -> String {
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "\\" {
                let next = s.index(after: i)
                guard next < s.endIndex else {
                    throw TOMLError.syntaxError("字符串转义不完整", line: line)
                }
                switch s[next] {
                case "b":  result.append("\u{0008}")
                case "t":  result.append("\t")
                case "n":  result.append("\n")
                case "f":  result.append("\u{000C}")
                case "r":  result.append("\r")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "u":
                    let hex = s[s.index(after: next)...].prefix(4)
                    guard hex.count == 4, let code = UInt32(hex, radix: 16), let scalar = UnicodeScalar(code) else {
                        throw TOMLError.syntaxError("无效的 Unicode 转义: \\u\(hex)", line: line)
                    }
                    result.append(String(scalar))
                    s.formIndex(&i, offsetBy: 6)
                    continue
                case "U":
                    let hex = s[s.index(after: next)...].prefix(8)
                    guard hex.count == 8, let code = UInt32(hex, radix: 16), let scalar = UnicodeScalar(code) else {
                        throw TOMLError.syntaxError("无效的 Unicode 转义: \\U\(hex)", line: line)
                    }
                    result.append(String(scalar))
                    s.formIndex(&i, offsetBy: 10)
                    continue
                case "\r":
                    let skip = s[next...].dropFirst()
                    if skip.first == "\n" {
                        s.formIndex(&i, offsetBy: 3)
                    } else {
                        s.formIndex(&i, offsetBy: 2)
                    }
                    continue
                case "\n":
                    s.formIndex(&i, offsetBy: 2)
                    continue
                default:
                    throw TOMLError.syntaxError("无效的转义字符: \\\(s[next])", line: line)
                }
                i = s.index(after: next)
            } else {
                result.append(s[i])
                i = s.index(after: i)
            }
        }
        return result
    }

    // MARK: - 数字解析

    private func tryParseNumber(_ str: String) -> Node? {
        if str.hasPrefix("0x") || str.hasPrefix("0X") {
            let hex = String(str.dropFirst(2)).replacingOccurrences(of: "_", with: "")
            if !hex.isEmpty && hex.allSatisfy({ $0.isHexDigit }) {
                return Node(.number(str))
            }
            return nil
        }
        if str.hasPrefix("0o") || str.hasPrefix("0O") {
            let oct = String(str.dropFirst(2)).replacingOccurrences(of: "_", with: "")
            if !oct.isEmpty && oct.allSatisfy({ $0 >= "0" && $0 <= "7" }) {
                return Node(.number(str))
            }
            return nil
        }
        if str.hasPrefix("0b") || str.hasPrefix("0B") {
            let bin = String(str.dropFirst(2)).replacingOccurrences(of: "_", with: "")
            if !bin.isEmpty && bin.allSatisfy({ $0 == "0" || $0 == "1" }) {
                return Node(.number(str))
            }
            return nil
        }
        let lower = str.lowercased()
        if lower == "inf" || lower == "+inf" || lower == "-inf" {
            return Node(.number(str))
        }
        if lower == "nan" || lower == "+nan" || lower == "-nan" {
            return Node(.number(str))
        }
        let cleaned = str.replacingOccurrences(of: "_", with: "")
        if cleaned.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" || $0 == "e" || $0 == "E" }) {
            if cleaned.contains(".") || cleaned.contains("e") || cleaned.contains("E") {
                if let _ = Double(cleaned) {
                    return Node(.number(str))
                }
            } else {
                if let _ = Int128(cleaned) {
                    return Node(.number(str))
                }
            }
        }
        return nil
    }

    // MARK: - 日期时间解析

    private func tryParseDateTime(_ str: String) -> Node? {
        if str.contains("T") || str.contains("t") {
            let upper = str.uppercased().replacingOccurrences(of: " ", with: "T")
            let dateTimePattern = "^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}"
            if let _ = try? NSRegularExpression(pattern: dateTimePattern).firstMatch(
                in: upper, range: NSRange(upper.startIndex..., in: upper)
            ) {
                return Node(.string(str))
            }
        }
        if str.count == 10 && str.hasPrefix("-") == false {
            let parts = str.split(separator: "-", omittingEmptySubsequences: false)
            if parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 {
                if parts[0].allSatisfy(\.isNumber), parts[1].allSatisfy(\.isNumber), parts[2].allSatisfy(\.isNumber) {
                    return Node(.string(str))
                }
            }
        }
        if str.count >= 5 && str.count <= 12 {
            let parts = str.split(separator: ":", omittingEmptySubsequences: false)
            if parts.count >= 2 {
                if parts[0].allSatisfy(\.isNumber) && parts[1].allSatisfy(\.isNumber) {
                    if parts.count == 2 || (parts.count == 3 && (parts[2].allSatisfy(\.isNumber) || parts[2].contains("."))) {
                        return Node(.string(str))
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 数组解析

    private mutating func parseArray(_ str: String, line: Int) throws -> Node {
        let inner = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty {
            return Node(.array([]))
        }
        let elements = try splitArrayElements(inner, line: line)
        var nodes: [Node] = []
        for elem in elements {
            let trimmed = elem.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let node = try parseValue(trimmed, line: line)
            nodes.append(node)
        }
        return Node(.array(nodes))
    }

    private func splitArrayElements(_ str: String, line: Int) throws -> [String] {
        var elements: [String] = []
        var current = ""
        var depth = 0
        var inSQ = false
        var inDQ = false
        var inMLDQ = false
        var inMLSQ = false
        var i = str.startIndex
        while i < str.endIndex {
            let ch = str[i]
            if !inSQ && !inMLSQ {
                if str[i...].hasPrefix("\"\"\"") {
                    if inDQ {
                        inMLDQ = false
                        current.append("\"\"\"")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    } else if !inDQ {
                        inMLDQ = true
                        current.append("\"\"\"")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    }
                }
                if str[i...].hasPrefix("'''") {
                    if inSQ {
                        inMLSQ = false
                        current.append("'''")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    } else if !inSQ {
                        inMLSQ = true
                        current.append("'''")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    }
                }
            }
            if !inDQ && !inMLDQ && !inSQ && !inMLSQ {
                if ch == "," && depth == 0 {
                    elements.append(current)
                    current = ""
                    i = str.index(after: i)
                    continue
                }
                if ch == "[" || ch == "{" { depth += 1 }
                if ch == "]" || ch == "}" { depth -= 1 }
            }
            if !inMLDQ && !inMLSQ {
                if ch == "'" && !inDQ { inSQ.toggle() }
                if ch == "\"" && !inSQ { inDQ.toggle() }
            }
            current.append(ch)
            i = str.index(after: i)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            elements.append(current)
        }
        return elements
    }

    // MARK: - 内联表解析

    private mutating func parseInlineTable(_ str: String, line: Int) throws -> Node {
        let inner = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        var dict = OrderedDictionary<String, Node>()
        if inner.isEmpty {
            return Node(.object(dict))
        }
        let pairs = try splitInlineTablePairs(inner, line: line)
        inInlineTable = true
        defer { inInlineTable = false }
        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            guard let eqPos = findFirstEquals(trimmed) else {
                throw TOMLError.syntaxError("内联表格式错误: \(trimmed)", line: line)
            }
            let keyStr = String(trimmed[..<eqPos]).trimmingCharacters(in: .whitespaces)
            let valueStr = String(trimmed[trimmed.index(after: eqPos)...]).trimmingCharacters(in: .whitespaces)
            let keys = try parseKey(keyStr, line: line)
            let value = try parseValue(valueStr, line: line)
            if keys.count == 1 {
                dict[keys[0]] = value
            } else {
                var current = Node(.object(dict))
                let prevKeys = keys.dropLast()
                for k in prevKeys {
                    var child = current[k]
                    if child.isNull {
                        child = Node(.object(OrderedDictionary<String, Node>()))
                        current[k] = child
                    }
                    current = child
                }
                current[keys.last!] = value
                if case .object(let d) = current.rawValue {
                    dict = d
                }
            }
        }
        return Node(.object(dict))
    }

    private func splitInlineTablePairs(_ str: String, line: Int) throws -> [String] {
        var pairs: [String] = []
        var current = ""
        var depth = 0
        var inSQ = false
        var inDQ = false
        var inMLDQ = false
        var inMLSQ = false
        var i = str.startIndex
        while i < str.endIndex {
            let ch = str[i]
            if !inSQ && !inMLSQ {
                if str[i...].hasPrefix("\"\"\"") {
                    if inDQ {
                        inMLDQ = false
                        current.append("\"\"\"")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    } else if !inDQ {
                        inMLDQ = true
                        current.append("\"\"\"")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    }
                }
                if str[i...].hasPrefix("'''") {
                    if inSQ {
                        inMLSQ = false
                        current.append("'''")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    } else if !inSQ {
                        inMLSQ = true
                        current.append("'''")
                        str.formIndex(&i, offsetBy: 3)
                        continue
                    }
                }
            }
            if !inDQ && !inMLDQ && !inSQ && !inMLSQ {
                if ch == "," && depth == 0 {
                    pairs.append(current)
                    current = ""
                    i = str.index(after: i)
                    continue
                }
                if ch == "{" || ch == "[" { depth += 1 }
                if ch == "}" || ch == "]" { depth -= 1 }
            }
            if !inMLDQ && !inMLSQ {
                if ch == "'" && !inDQ { inSQ.toggle() }
                if ch == "\"" && !inSQ { inDQ.toggle() }
            }
            current.append(ch)
            i = str.index(after: i)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            pairs.append(current)
        }
        return pairs
    }

    // MARK: - 键解析

    private func parseTableKeyPath(_ str: String, line: Int) throws -> [String] {
        return try splitKeyPath(str, line: line)
    }

    private func splitKeyPath(_ str: String, line: Int) throws -> [String] {
        var segments: [String] = []
        var current = ""
        var inSQ = false
        var inDQ = false
        var i = str.startIndex
        while i < str.endIndex {
            let ch = str[i]
            if inSQ {
                if ch == "'" {
                    inSQ = false
                    current.append(ch)
                    i = str.index(after: i)
                    continue
                }
                current.append(ch)
                i = str.index(after: i)
                continue
            }
            if inDQ {
                if ch == "\"" {
                    inDQ = false
                    current.append(ch)
                    i = str.index(after: i)
                    continue
                }
                current.append(ch)
                i = str.index(after: i)
                continue
            }
            if ch == "." {
                if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                    segments.append(cleanKey(current))
                }
                current = ""
                i = str.index(after: i)
                continue
            }
            if ch == "'" {
                inSQ = true
                current.append(ch)
                i = str.index(after: i)
                continue
            }
            if ch == "\"" {
                inDQ = true
                current.append(ch)
                i = str.index(after: i)
                continue
            }
            current.append(ch)
            i = str.index(after: i)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            segments.append(cleanKey(current))
        }
        if segments.isEmpty {
            throw TOMLError.syntaxError("空的键路径", line: line)
        }
        return segments
    }

    private func cleanKey(_ str: String) -> String {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private func parseKey(_ str: String, line: Int) throws -> [String] {
        return try splitKeyPath(str, line: line)
    }

    // MARK: - 键值分割

    private func splitKeyValue(_ line: String, lineIndex: Int) throws -> ([String], String) {
        var inSQ = false
        var inDQ = false
        var eqPos: String.Index?
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "'" && !inDQ { inSQ.toggle() }
            if ch == "\"" && !inSQ { inDQ.toggle() }
            if !inSQ && !inDQ && ch == "=" {
                eqPos = i
                break
            }
            i = line.index(after: i)
        }
        guard let pos = eqPos else {
            throw TOMLError.syntaxError("缺少 = 分隔符", line: lineIndex)
        }
        let keyStr = String(line[..<pos]).trimmingCharacters(in: .whitespaces)
        let valueStr = String(line[line.index(after: pos)...])
        let keys = try parseKey(keyStr, line: lineIndex)
        return (keys, valueStr)
    }

    private func findFirstEquals(_ str: String) -> String.Index? {
        var inSQ = false
        var inDQ = false
        var i = str.startIndex
        while i < str.endIndex {
            let ch = str[i]
            if ch == "'" && !inDQ { inSQ.toggle() }
            if ch == "\"" && !inSQ { inDQ.toggle() }
            if !inSQ && !inDQ && ch == "=" {
                return i
            }
            i = str.index(after: i)
        }
        return nil
    }

    // MARK: - Node 值类型安全导航

    /// 判断节点是否为对象（非 error/null 对象）
    private func isObjectNode(_ node: Node) -> Bool {
        if case .object = node.rawValue { return true }
        return false
    }

    /// 从 root 中按路径获取节点，遇到非对象节点停止
    private func nodeAtPath(_ path: [String], in node: Node) -> Node {
        var current = node
        for segment in path {
            guard isObjectNode(current) else { break }
            current = current[segment]
        }
        return current
    }

    /// 按路径设置节点值，路径长度>1 时自动创建中间对象节点
    private func setNodeAtPath(_ path: [String], in node: Node, to value: Node, createIntermediates: Bool = false) -> Node {
        guard !path.isEmpty else { return value }
        var result = node
        let key = path[0]
        if path.count == 1 {
            result[key] = value
            return result
        }
        let rest = Array(path.dropFirst())
        var child = result[key]
        // 对于多级路径，始终创建中间节点
        if child.rawValue == .null || child.isNull {
            child = Node(.object(OrderedDictionary<String, Node>()))
        }
        child = setNodeAtPath(rest, in: child, to: value, createIntermediates: createIntermediates)
        result[key] = child
        return result
    }

    // MARK: - 注释处理

    private func extractComment(_ line: String) -> String {
        var s = line
        if s.hasPrefix("#") {
            s = String(s.dropFirst())
        }
        if s.hasPrefix(" ") {
            s = String(s.dropFirst())
        }
        return s
    }

    private func splitInlineComment(_ line: String) -> (String, String?) {
        var inSQ = false
        var inDQ = false
        var hashPos: String.Index?
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "'" && !inDQ { inSQ.toggle() }
            if ch == "\"" && !inSQ { inDQ.toggle() }
            if !inSQ && !inDQ && ch == "#" {
                hashPos = i
                break
            }
            i = line.index(after: i)
        }
        if let pos = hashPos {
            let value = String(line[..<pos])
            let comment = String(line[line.index(after: pos)...]).trimmingCharacters(in: .whitespaces)
            return (value, comment.isEmpty ? nil : comment)
        }
        return (line, nil)
    }
}
