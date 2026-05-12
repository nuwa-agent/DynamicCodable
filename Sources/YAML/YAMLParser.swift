//
//  YAMLParser.swift
//  Nuwa
//
//  YAML 文本解析器：将 YAML 字符串解析为 Node 树，完整保留注释信息
//
//  解析流程：
//    1. 按行分割，通过缩进栈管理嵌套层级
//    2. 注释行累积为 pendingComments，遇到实际节点时附加
//    3. 序列项连续出现时复用同一容器
//    4. 映射键 "key:" 无值时标记为 danglingKey，等待后续行
//    5. 块标量 (|, >) 由调用方在外部通过 lookahead 识别
//

import Foundation
import DynamicCodable

/// YAML 文本解析器
public struct YAMLParser {

    public init() {}

    /// 解析 YAML 字符串为 Node 树
    public func parse(_ yaml: String) throws -> Node {
        var lines = yaml.components(separatedBy: .newlines)
        // 预处理：将块标量标记行和其后续内容合并处理
        lines = try preprocessBlockScalars(lines)
        let state = ParseState(lines: lines)
        try state.parseAll()
        return state.root()
    }

    // MARK: - 块标量预处理

    /// 预处理：识别 | 和 > 块标量，将多行内容合并到标记行
    /// 这样后续解析器只需按普通行处理即可
    private func preprocessBlockScalars(_ lines: [String]) throws -> [String] {
        var result: [String] = []
        var i = 0
        while i < lines.count {
            let rawLine = lines[i]
            let (indent, content) = parseIndent(rawLine)
            // 检查是否是块标量标记行（| 或 > 开头的值）
            if isBlockScalarIndicator(content) {
                // 读取后续的缩进块
                let blockLines = readIndentedBlock(from: lines, startIndex: i + 1, baseIndent: indent)
                // 合并为单行：使用 \n 连接，序列化时会按原样处理
                let combined = String(repeating: " ", count: indent) + "\"" + blockLines.joined(separator: "\\n") + "\""
                result.append(combined)
                i = i + 1 + blockLines.count
            } else {
                result.append(rawLine)
                i += 1
            }
        }
        return result
    }

    /// 检查去除缩进和键名后的值部分是否以 | 或 > 开头
    private func isBlockScalarIndicator(_ content: String) -> Bool {
        // 检查 "key: |" 或 "key: >" 或 "- |" 或 "- >" 模式
        // 找到冒号后的部分
        if let colonPos = findColonOutsideQuotes(content) {
            let after = content[content.index(content.startIndex, offsetBy: colonPos + 1)...]
                .trimmingCharacters(in: .whitespaces)
            return after.hasPrefix("|") || after.hasPrefix(">")
        }
        // 序列项后的块标量: "- |" 或 "- >"
        if content.hasPrefix("- ") || content == "-" {
            let itemPart = String(content.dropFirst(content.hasPrefix("- ") ? 2 : 1))
                .trimmingCharacters(in: .whitespaces)
            return itemPart.hasPrefix("|") || itemPart.hasPrefix(">")
        }
        return false
    }

    /// 读取一个缩进块（从 startIndex 开始，所有缩进大于 baseIndent 的行）
    private func readIndentedBlock(from lines: [String], startIndex: Int, baseIndent: Int) -> [String] {
        var block: [String] = []
        var i = startIndex
        while i < lines.count {
            let (indent, content) = parseIndent(lines[i])
            // 空行保留
            if content.isEmpty {
                block.append("")
                i += 1
                continue
            }
            // 缩进不足则块结束
            if indent <= baseIndent { break }
            // 去除基础缩进 + 2（块标量内容通常比键缩进多）
            let strip = min(indent, baseIndent + 2)
            block.append(String(lines[i].dropFirst(strip)))
            i += 1
        }
        return block
    }

    // MARK: - 静态辅助

    private func parseIndent(_ line: String) -> (indent: Int, content: String) {
        var count = 0
        for char in line {
            if char == " " { count += 1 }
            else if char == "\t" { count += 2 }
            else { break }
        }
        return (count, String(line.dropFirst(min(count, line.count))))
    }

    private func findColonOutsideQuotes(_ str: String) -> Int? {
        var inSQ = false, inDQ = false
        let chars = Array(str)
        for i in 0..<chars.count {
            switch chars[i] {
            case "\'": if !inDQ { inSQ.toggle() }
            case "\"": if !inSQ { inDQ.toggle() }
            case ":":  if !inSQ && !inDQ { return i }
            default: break
            }
        }
        return nil
    }

    private func findHashOutsideQuotes(_ str: String) -> Int? {
        var inSQ = false, inDQ = false
        let chars = Array(str)
        for i in 0..<chars.count {
            switch chars[i] {
            case "\'": if !inDQ { inSQ.toggle() }
            case "\"": if !inSQ { inDQ.toggle() }
            case "#":  if !inSQ && !inDQ { return i }
            default: break
            }
        }
        return nil
    }
}

// MARK: - 解析状态机

private final class ParseState {

    let lines: [String]
    var lineIndex: Int = 0
    var stack: [StackFrame] = []
    var pendingComments: [String] = []
    var danglingKey: String? = nil
    /// 上一个序列容器帧（用于同缩进的序列项复用）
    var lastSeqFrame: StackFrame? = nil
    /// 上一个序列的缩进
    var lastSeqIndent: Int? = nil

    init(lines: [String]) {
        self.lines = lines
        let root = Node(.object(OrderedDictionary<String, Node>()))
        self.stack = [StackFrame(indent: -1, kind: .mapping, node: root)]
    }

    // MARK: 主循环

    func parseAll() throws {
        while lineIndex < lines.count {
            try parseLine()
        }
        if let key = danglingKey, let parent = stack.last {
            _ = try setMappingValue(in: parent, key: key, value: Node.null)
            danglingKey = nil
        }
    }

    private func parseLine() throws {
        let rawLine = lines[lineIndex]
        lineIndex += 1

        let (indent, content) = parseIndent(rawLine)

        // 空行
        if content.isEmpty { return }

        // 注释行：累积
        if content.hasPrefix("#") {
            pendingComments.append(extractComment(content))
            return
        }

        // 文档分隔符：重置
        if content == "---" || content == "..." {
            pendingComments.removeAll()
            danglingKey = nil
            lastSeqFrame = nil
            lastSeqIndent = nil
            return
        }

        // 弹栈到父层级
        popStack(to: indent)
        guard let parent = stack.last else { return }

        // 检查是否打破了上一个序列的连续性
        if let lastIndent = lastSeqIndent, indent != lastIndent {
            lastSeqFrame = nil
            lastSeqIndent = nil
        }

        // 流式风格
        if let node = try parseFlowStyle(content) {
            try assignParsedValue(node, to: parent)
            pendingComments.removeAll()
            return
        }

        // 序列项
        if isSequenceItem(content) {
            try handleSequenceItem(content: content, indent: indent, parent: parent)
            return
        }

        // 映射键
        if isMappingKey(content) {
            try handleMappingKey(content: content, indent: indent, parent: parent)
            // 序列被映射键打断
            lastSeqFrame = nil
            lastSeqIndent = nil
            return
        }

        // 纯量行
        if let key = danglingKey {
            try handleScalarLine(content: content, parent: parent)
        }
        // 否则忽略（根级别的纯量行暂时丢弃）
    }

    // MARK: 缩进

    private func parseIndent(_ line: String) -> (Int, String) {
        var count = 0
        for char in line {
            if char == " " { count += 1 }
            else if char == "\t" { count += 2 }
            else { break }
        }
        return (count, String(line.dropFirst(min(count, line.count))))
    }

    private func popStack(to indent: Int) {
        while stack.count > 1 && stack.last!.indent > indent {
            stack.removeLast()
        }
    }

    // MARK: 行识别

    private func extractComment(_ content: String) -> String {
        let t = content.dropFirst()
        return t.first == " " ? String(t.dropFirst()) : String(t)
    }

    private func isSequenceItem(_ content: String) -> Bool {
        return content.hasPrefix("- ") || content == "-"
    }

    private func isMappingKey(_ content: String) -> Bool {
        return findColonOutsideQuotes(content) != nil
    }

    private func findColonOutsideQuotes(_ str: String) -> Int? {
        var inSQ = false, inDQ = false
        let chars = Array(str)
        for i in 0..<chars.count {
            switch chars[i] {
            case "\'": if !inDQ { inSQ.toggle() }
            case "\"": if !inSQ { inDQ.toggle() }
            case ":":  if !inSQ && !inDQ { return i }
            default: break
            }
        }
        return nil
    }

    private func findHashOutsideQuotes(_ str: String) -> Int? {
        var inSQ = false, inDQ = false
        let chars = Array(str)
        for i in 0..<chars.count {
            switch chars[i] {
            case "\'": if !inDQ { inSQ.toggle() }
            case "\"": if !inSQ { inDQ.toggle() }
            case "#":  if !inSQ && !inDQ { return i }
            default: break
            }
        }
        return nil
    }

    private func splitInlineComment(_ str: String) -> (value: String, comment: String?) {
        guard let pos = findHashOutsideQuotes(str) else { return (str, nil) }
        let v = String(str[..<str.index(str.startIndex, offsetBy: pos)])
            .trimmingCharacters(in: .whitespaces)
        let c = String(str[str.index(str.startIndex, offsetBy: pos + 1)...])
            .trimmingCharacters(in: .whitespaces)
        return (v, c.isEmpty ? nil : c)
    }

    // MARK: 流式风格

    private func parseFlowStyle(_ content: String) throws -> Node? {
        if content.hasPrefix("[") && content.hasSuffix("]") {
            return try parseFlowArray(content)
        }
        if content.hasPrefix("{") && content.hasSuffix("}") {
            return try parseFlowMapping(content)
        }
        return nil
    }

    private func parseFlowArray(_ content: String) throws -> Node {
        let inner = String(content.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return Node(.array([])) }
        return Node(.array(splitFlowTokens(inner).map(parseScalarValue)))
    }

    private func parseFlowMapping(_ content: String) throws -> Node {
        let inner = String(content.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return Node(.object(OrderedDictionary())) }
        var dict = OrderedDictionary<String, Node>()
        for part in splitFlowTokens(inner) {
            guard let cp = findColonOutsideQuotes(part) else {
                throw YAMLError.syntaxError("流式映射缺少冒号: \(part)", line: lineIndex - 1)
            }
            let k = String(part[..<part.index(part.startIndex, offsetBy: cp)]).trimmingCharacters(in: .whitespaces)
            let v = String(part[part.index(part.startIndex, offsetBy: cp + 1)...]).trimmingCharacters(in: .whitespaces)
            dict[unquote(k)] = parseScalarValue(v)
        }
        return Node(.object(dict))
    }

    private func splitFlowTokens(_ str: String) -> [String] {
        var parts: [String] = []
        var cur = ""
        var depth = 0
        var inSQ = false, inDQ = false
        for ch in str {
            if ch == "\'" && !inDQ { inSQ.toggle(); cur.append(ch); continue }
            if ch == "\"" && !inSQ { inDQ.toggle(); cur.append(ch); continue }
            if (ch == "[" || ch == "{") && !inSQ && !inDQ { depth += 1; cur.append(ch); continue }
            if (ch == "]" || ch == "}") && !inSQ && !inDQ { depth -= 1; cur.append(ch); continue }
            if ch == "," && depth == 0 && !inSQ && !inDQ {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { parts.append(t) }
                cur = ""
                continue
            }
            cur.append(ch)
        }
        let t = cur.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { parts.append(t) }
        return parts
    }

    private func unquote(_ str: String) -> String {
        let t = str.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("\"") && t.hasSuffix("\"") { return String(t.dropFirst().dropLast()) }
        if t.hasPrefix("'") && t.hasSuffix("'") { return String(t.dropFirst().dropLast()) }
        return str
    }

    private func parseScalarValue(_ str: String) -> Node {
        let t = str.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return Node(.string(t)) }
        // 引号字符串
        if t.hasPrefix("\"") && t.hasSuffix("\"") { return Node(.string(String(t.dropFirst().dropLast()))) }
        if t.hasPrefix("'") && t.hasSuffix("'") { return Node(.string(String(t.dropFirst().dropLast()))) }
        // 布尔/空
        switch t.lowercased() {
        case "true", "yes", "on":  return Node(.bool(true))
        case "false", "no", "off": return Node(.bool(false))
        case "null", "~":          return Node(.null)
        default: break
        }
        // 数字
        if let _ = Int128(t) { return Node(.number(t)) }
        if let _ = Double(t) { return Node(.number(t)) }
        return Node(.string(t))
    }

    // MARK: 序列项

    private func handleSequenceItem(content: String, indent: Int, parent: StackFrame) throws {
        let itemContent = String(content.dropFirst(content.hasPrefix("- ") ? 2 : 1))
            .trimmingCharacters(in: .whitespaces)
        let (valueStr, inlineComment) = splitInlineComment(itemContent)

        // 获取或创建序列容器
        let seqFrame: StackFrame
        if let existing = lastSeqFrame, existing.indent == indent {
            seqFrame = existing
        } else {
            var effectiveParent = parent
            // 如果 indent > parent.indent 且有 danglingKey，先创建嵌套映射
            if indent > parent.indent, let dk = danglingKey {
                let nestedObj = Node(.object(OrderedDictionary()))
                _ = try setMappingValue(in: parent, key: dk, value: nestedObj)
                let nestedFrame = StackFrame(indent: indent, kind: .mapping, node: nestedObj)
                nestedFrame.parentFrame = parent
                nestedFrame.parentKey = dk
                effectiveParent = nestedFrame
                stack.append(nestedFrame)
                danglingKey = nil
            }
            seqFrame = try createSequenceContainer(indent: indent, parent: effectiveParent)
            lastSeqFrame = seqFrame
            lastSeqIndent = indent
            stack.append(seqFrame)
        }

        if !valueStr.isEmpty || inlineComment != nil {
            var node = parseScalarValue(valueStr)
            node.inlineComment = inlineComment
            if !pendingComments.isEmpty { node.comments = pendingComments; pendingComments.removeAll() }
            try appendToSequence(in: seqFrame, item: node)
        }
    }

    private func createSequenceContainer(indent: Int, parent: StackFrame) throws -> StackFrame {
        let seqNode: Node
        let childKey: String
        if let key = danglingKey {
            seqNode = Node(.array([]))
            _ = try setMappingValue(in: parent, key: key, value: seqNode)
            childKey = key
            danglingKey = nil
        } else {
            seqNode = Node(.array([]))
            let idx = parent.node.objectCount
            try appendToContainer(in: parent, value: seqNode)
            childKey = "_\(idx)"
        }
        let frame = StackFrame(indent: indent, kind: .sequence, node: seqNode)
        frame.parentFrame = parent
        frame.parentKey = childKey
        return frame
    }

    // MARK: 映射键

    private func handleMappingKey(content: String, indent: Int, parent: StackFrame) throws {
        // 如果 indent > parent.indent 且有 danglingKey，先创建嵌套映射容器
        var effectiveParent = parent
        if indent > parent.indent, let key = danglingKey {
            let nestedObj = Node(.object(OrderedDictionary()))
            _ = try setMappingValue(in: parent, key: key, value: nestedObj)
            let nestedFrame = StackFrame(indent: indent, kind: .mapping, node: nestedObj)
            nestedFrame.parentFrame = parent
            nestedFrame.parentKey = key
            effectiveParent = nestedFrame
            stack.append(nestedFrame)
            danglingKey = nil
        }

        try flushDanglingKey(in: effectiveParent)

        guard let colonPos = findColonOutsideQuotes(content) else { return }

        let key = String(content[..<content.index(content.startIndex, offsetBy: colonPos)])
            .trimmingCharacters(in: .whitespaces)
        let after = String(content[content.index(content.startIndex, offsetBy: colonPos + 1)...])
            .trimmingCharacters(in: .whitespaces)
        let (valueStr, inlineComment) = splitInlineComment(after)

        try ensureMapping(in: effectiveParent)

        if valueStr.isEmpty && inlineComment == nil {
            danglingKey = key
        } else if !valueStr.isEmpty {
            var node = parseScalarValue(valueStr)
            node.inlineComment = inlineComment
            if !pendingComments.isEmpty { node.comments = pendingComments; pendingComments.removeAll() }
            _ = try setMappingValue(in: effectiveParent, key: key, value: node)
            danglingKey = nil
        } else {
            danglingKey = key
        }
    }

    private func flushDanglingKey(in parent: StackFrame) throws {
        guard let key = danglingKey else { return }
        _ = try setMappingValue(in: parent, key: key, value: Node.null)
        danglingKey = nil
        pendingComments.removeAll()
    }

    // MARK: 纯量行

    private func handleScalarLine(content: String, parent: StackFrame) throws {
        let (valueStr, inlineComment) = splitInlineComment(content)
        guard let key = danglingKey else { return }

        let (indent, _) = parseIndent(lines[lineIndex - 1])
        var effectiveParent = parent
        if indent > parent.indent {
            let nestedObj = Node(.object(OrderedDictionary()))
            _ = try setMappingValue(in: parent, key: key, value: nestedObj)
            let nestedFrame = StackFrame(indent: indent, kind: .mapping, node: nestedObj)
            nestedFrame.parentFrame = parent
            nestedFrame.parentKey = key
            effectiveParent = nestedFrame
            stack.append(nestedFrame)
            danglingKey = nil
            let node = parseScalarValue(valueStr)
            _ = try setMappingValue(in: nestedFrame, key: "_value", value: node)
            return
        }

        var node = parseScalarValue(valueStr)
        node.inlineComment = inlineComment
        if !pendingComments.isEmpty { node.comments = pendingComments; pendingComments.removeAll() }
        _ = try setMappingValue(in: effectiveParent, key: key, value: node)
        danglingKey = nil
    }

    // MARK: 值分配

    private func assignParsedValue(_ node: Node, to parent: StackFrame) throws {
        if let key = danglingKey {
            _ = try setMappingValue(in: parent, key: key, value: node)
            danglingKey = nil
        } else if parent.kind == .sequence {
            try appendToSequence(in: parent, item: node)
        } else {
            try ensureMapping(in: parent)
            let key = "_\(parent.node.objectCount)"
            _ = try setMappingValue(in: parent, key: key, value: node)
        }
    }

    // MARK: 容器操作

    private func ensureMapping(in frame: StackFrame) throws {
        if case .object = frame.node.rawValue { return }
        if case .null = frame.node.rawValue {
            frame.node = Node(.object(OrderedDictionary()))
            frame.syncToParent()
            return
        }
        var dict = OrderedDictionary<String, Node>()
        dict["_value"] = frame.node
        frame.node = Node(.object(dict))
        frame.syncToParent()
    }

    @discardableResult
    private func setMappingValue(in frame: StackFrame, key: String, value: Node) throws -> Node {
        if case .object(var dict) = frame.node.rawValue {
            dict[key] = value
            frame.node = Node(.object(dict))
            frame.syncToParent()
        } else if case .null = frame.node.rawValue {
            var dict = OrderedDictionary<String, Node>()
            dict[key] = value
            frame.node = Node(.object(dict))
            frame.syncToParent()
        } else {
            var dict = OrderedDictionary<String, Node>()
            dict["_value"] = frame.node
            dict[key] = value
            frame.node = Node(.object(dict))
            frame.syncToParent()
        }
        return value
    }

    private func appendToSequence(in frame: StackFrame, item: Node) throws {
        if case .array(var arr) = frame.node.rawValue {
            arr.append(item)
            frame.node = Node(.array(arr))
            frame.syncToParent()
        } else if case .null = frame.node.rawValue {
            frame.node = Node(.array([item]))
            frame.syncToParent()
        } else {
            frame.node = Node(.array([frame.node, item]))
            frame.syncToParent()
        }
    }

    private func appendToContainer(in frame: StackFrame, value: Node) throws {
        switch frame.kind {
        case .sequence:
            try appendToSequence(in: frame, item: value)
        case .mapping:
            try ensureMapping(in: frame)
            _ = try setMappingValue(in: frame, key: "_\(frame.node.objectCount)", value: value)
        }
    }

    // MARK: 结果

    func root() -> Node {
        let r = stack.first?.node ?? Node.null
        if case .object(let dict) = r.rawValue, dict.isEmpty {
            return Node.null
        }
        return r
    }
}

// MARK: - 栈帧

/// 解析栈中的一个层级帧
/// 记录缩进、容器类型和对应的可变 Node
/// parentFrame / parentKey 用于在修改后将值同步回父容器
private final class StackFrame {
    /// 当前层级的缩进空格数
    let indent: Int
    /// 容器类型
    let kind: ContainerKind
    /// 可变 Node
    var node: Node
    /// 父栈帧（弱引用，避免循环）
    weak var parentFrame: StackFrame?
    /// 在父容器中的键名（映射）或索引（数组）
    var parentKey: String?

    init(indent: Int, kind: ContainerKind, node: Node) {
        self.indent = indent
        self.kind = kind
        self.node = node
    }

    /// 将当前节点的修改同步回父容器
    func syncToParent() {
        guard let parent = parentFrame, let key = parentKey else { return }
        switch parent.kind {
        case .mapping:
            if case .object(var dict) = parent.node.rawValue {
                dict[key] = node
                parent.node = Node(.object(dict))
            }
        case .sequence:
            // 父容器是序列，需要按索引更新
            if let index = Int(key), case .array(var arr) = parent.node.rawValue, index < arr.count {
                arr[index] = node
                parent.node = Node(.array(arr))
            }
        }
    }
}

private enum ContainerKind {
    case mapping
    case sequence
}

extension Node {
    var objectCount: Int {
        if case .object(let dict) = rawValue { return dict.count }
        return 0
    }
}
