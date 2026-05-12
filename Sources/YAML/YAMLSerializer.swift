//
//  YAMLSerializer.swift
//  Nuwa
//
//  Node 树序列化为 YAML 文本，完整还原注释和多行格式
//
//  序列化规则：
//    1. 前导注释：在节点前输出 "# comment"，多行注释按原样输出
//    2. 内联注释：在值后同行的 " # comment" 格式输出
//    3. 对象：key: 后换行缩进，嵌套子节点
//    4. 序列：- item 格式，连续输出
//    5. 字符串：智能选择引号或裸字符串
//    6. 多行字符串：使用 | 块标量格式输出
//    7. 数字/布尔/null：按 YAML 格式输出
//

import Foundation
import DynamicCodable

/// YAML 序列化器
/// 将 Node 树转换为 YAML 格式的字符串，保留注释信息
public struct YAMLSerializer {

    /// 缩进空格数（默认 2）
    public var indentCount: Int
    /// 是否输出注释，默认 true
    public var includeComments: Bool

    public init(indentCount: Int = 2, includeComments: Bool = true) {
        self.indentCount = indentCount
        self.includeComments = includeComments
    }

    // MARK: - 公开序列化入口

    /// 将 Node 序列化为 YAML 字符串
    /// - Parameter node: 要序列化的 Node 树
    /// - Returns: YAML 格式的字符串
    public func serialize(_ node: Node) -> String {
        var result = ""
        serializeNode(node, indent: 0, isRoot: true, result: &result)
        // 确保末尾有换行
        if !result.isEmpty && result.last != "\n" {
            result.append("\n")
        }
        return result
    }

    // MARK: - 核心序列化方法

    /// 递归序列化单个节点
    /// - Parameters:
    ///   - node: 当前节点
    ///   - indent: 当前缩进层级（空格数）
    ///   - isRoot: 是否为根节点（根节点不需要缩进前缀）
    ///   - result: 累积结果的字符串
    private func serializeNode(
        _ node: Node,
        indent: Int,
        isRoot: Bool = false,
        result: inout String
    ) {
        // 1) 输出前导注释（多行保持原格式）
        writeLeadingComments(node.comments, indent: indent, to: &result)

        // 2) 输出缩进前缀
        if !isRoot {
            result.append(indentString(indent))
        }

        // 3) 按值类型分发序列化
        switch node.rawValue {
        case .null:
            result.append("null")
            writeInlineComment(node.inlineComment, to: &result)

        case .bool(let value):
            result.append(value ? "true" : "false")
            writeInlineComment(node.inlineComment, to: &result)

        case .number(let value):
            result.append(value)
            writeInlineComment(node.inlineComment, to: &result)

        case .string(let value):
            writeString(value, inlineComment: node.inlineComment, indent: indent, to: &result)

        case .array(let items):
            writeSequence(items: items, indent: indent, to: &result)

        case .object(let dict):
            writeMapping(dict: dict, indent: indent, isRoot: isRoot, to: &result)

        case .error(let error, let ignore):
            result.append("# Error: \(error.localizedDescription) path: \(ignore.joined(separator: "/"))\n")
        }
    }

    // MARK: - 字符串输出

    /// 输出字符串值，自动判断是否需要引号和块标量
    private func writeString(
        _ value: String,
        inlineComment: String?,
        indent: Int,
        to result: inout String
    ) {
        // 包含换行符 → 使用 | 块标量格式
        if value.contains("\n") {
            result.append("|\n")
            let subIndent = indent + indentCount
            let lines = value.components(separatedBy: .newlines)
            for line in lines {
                result.append(indentString(subIndent))
                result.append(line)
                result.append("\n")
            }
            // 内联注释在块标量后单独输出
            if let ic = inlineComment {
                result.append(indentString(indent))
                result.append("# \(ic)\n")
            }
            return
        }

        // 需要引号的情况：特殊字符、空字符串、数字样字符串
        let needsQuoting = needsDoubleQuotes(value)

        if needsQuoting {
            let escaped = escapeString(value)
            result.append("\"\(escaped)\"")
        } else {
            result.append(value)
        }
        writeInlineComment(inlineComment, to: &result)
    }

    /// 判断字符串是否需要双引号包裹
    private func needsDoubleQuotes(_ str: String) -> Bool {
        if str.isEmpty { return true }
        // YAML 特殊字符
        let special: Set<Character> = [":", "#", "{", "}", "[", "]", ",", "&", "*", "?", "|", "-", "<", ">", "=", "!", "%", "@", "`", "\"", "\'"]
        // 以特殊字符开头或包含会被误解的内容
        for char in str {
            if special.contains(char) { return true }
        }
        // 纯数字样式的字符串需要引号（防止被解析为数字）
        if let _ = Double(str) { return true }
        // 看起来像布尔或 null
        switch str.lowercased() {
        case "true", "false", "yes", "no", "on", "off", "null", "~":
            return true
        default: break
        }
        // 以空格开头或结尾
        if str.hasPrefix(" ") || str.hasSuffix(" ") { return true }
        return false
    }

    /// 转义字符串中的双引号和反斜杠
    private func escapeString(_ str: String) -> String {
        var result = ""
        for char in str {
            switch char {
            case "\\": result.append("\\\\")
            case "\"": result.append("\\\"")
            case "\n": result.append("\\n")
            case "\t": result.append("\\t")
            case "\r": result.append("\\r")
            default: result.append(char)
            }
        }
        return result
    }

    // MARK: - 序列（数组）输出

    /// 输出序列 "- item" 格式
    private func writeSequence(
        items: [Node],
        indent: Int,
        to result: inout String
    ) {
        // 空数组
        if items.isEmpty {
            result.append("[]\n")
            return
        }

        // 检查是否都是简单标量（可以写在一行）
        if items.allSatisfy({ isSimpleScalar($0) }) && items.count <= 5 {
            result.append("[")
            result.append(items.map { scalarToString($0) }.joined(separator: ", "))
            result.append("]\n")
            return
        }

        result.append("\n")
        let itemIndent = indent + indentCount
        for item in items {
            // 每个序列项的前导注释
            writeLeadingComments(item.comments, indent: itemIndent, to: &result)

            switch item.rawValue {
            case .object:
                // 对象嵌套："- key: value" 方式
                result.append(indentString(itemIndent))
                result.append("- ")
                serializeObjectInline(item, indent: itemIndent + 2, to: &result)
            case .array:
                result.append(indentString(itemIndent))
                result.append("-")
                writeSequence(items: item.rawValue.arrayValue ?? [], indent: itemIndent, to: &result)
            case .string(let str):
                result.append(indentString(itemIndent))
                result.append("- ")
                let needQuote = needsDoubleQuotes(str)
                if needQuote {
                    result.append("\"\(escapeString(str))\"")
                } else {
                    result.append(str)
                }
                writeInlineComment(item.inlineComment, to: &result)
            default:
                result.append(indentString(itemIndent))
                result.append("- ")
                writeScalarItem(item, to: &result)
                writeInlineComment(item.inlineComment, to: &result)
            }
        }
    }

    /// 判断是否为简单标量（可在流式中显示）
    private func isSimpleScalar(_ node: Node) -> Bool {
        switch node.rawValue {
        case .null, .bool, .number, .string: return true
        default: return false
        }
    }

    /// 将标量转为字符串
    private func scalarToString(_ node: Node) -> String {
        switch node.rawValue {
        case .null: return "null"
        case .bool(let v): return v ? "true" : "false"
        case .number(let v): return v
        case .string(let v):
            if needsDoubleQuotes(v) {
                return "\"\(escapeString(v))\""
            }
            return v
        default: return ""
        }
    }

    /// 输出序列项中的标量（不换行）
    private func writeScalarItem(_ node: Node, to result: inout String) {
        switch node.rawValue {
        case .null: result.append("null")
        case .bool(let v): result.append(v ? "true" : "false")
        case .number(let v): result.append(v)
        case .string(let v):
            if needsDoubleQuotes(v) {
                result.append("\"\(escapeString(v))\"")
            } else {
                result.append(v)
            }
        case .array(let items):
            result.append("[")
            result.append(items.map { scalarToString($0) }.joined(separator: ", "))
            result.append("]")
        case .object:
            serializeObjectInline(node, indent: 0, to: &result)
        case .error:
            result.append("null")
        }
    }

    // MARK: - 映射（对象）输出

    /// 输出对象 mapping
    private func writeMapping(
        dict: OrderedDictionary<String, Node>,
        indent: Int,
        isRoot: Bool,
        to result: inout String
    ) {
        if dict.isEmpty {
            result.append(isRoot ? "" : "{}\n")
            return
        }
        if !isRoot {
            result.append("\n")
        }
        let childIndent = indent + indentCount
        for (key, value) in dict {
            // 跳过内部自动生成的键名
            if key.hasPrefix("_") {
                // 仍序列化其值，但不输出键名
                serializeNode(value, indent: indent, isRoot: false, result: &result)
                continue
            }

            // 子节点的前导注释
            writeLeadingComments(value.comments, indent: childIndent, to: &result)

            // 键名
            result.append(indentString(childIndent))
            result.append("\(key):")

            // 值
            switch value.rawValue {
            case .object:
                serializeNode(value, indent: childIndent, isRoot: false, result: &result)
            case .array:
                result.append("\n")
                writeSequence(items: value.rawValue.arrayValue ?? [], indent: childIndent, to: &result)
            case .null:
                result.append(" null")
                writeInlineComment(value.inlineComment, to: &result)
            case .bool(let v):
                result.append(" \(v ? "true" : "false")")
                writeInlineComment(value.inlineComment, to: &result)
            case .number(let v):
                result.append(" \(v)")
                writeInlineComment(value.inlineComment, to: &result)
            case .string(let str):
                if str.contains("\n") {
                    // 多行字符串使用块标量
                    result.append(" |\n")
                    let lines = str.components(separatedBy: .newlines)
                    for line in lines {
                        result.append(indentString(childIndent + indentCount))
                        result.append(line)
                        result.append("\n")
                    }
                    if let ic = value.inlineComment {
                        result.append(indentString(childIndent))
                        result.append("# \(ic)\n")
                    }
                } else if needsDoubleQuotes(str) {
                    result.append(" \"\(escapeString(str))\"")
                    writeInlineComment(value.inlineComment, to: &result)
                } else {
                    result.append(" \(str)")
                    writeInlineComment(value.inlineComment, to: &result)
                }
            case .error:
                result.append(" null")
            }
        }
    }

    /// 内联序列化对象（用于流式格式和序列嵌套）
    private func serializeObjectInline(_ node: Node, indent: Int, to result: inout String) {
        guard case .object(let dict) = node.rawValue else { return }
        if dict.isEmpty {
            result.append("{}\n")
            return
        }
        result.append("\n")
        let childIndent = indent
        for (key, value) in dict {
            if key.hasPrefix("_") {
                serializeNode(value, indent: indent, isRoot: false, result: &result)
                continue
            }
            writeLeadingComments(value.comments, indent: childIndent, to: &result)
            result.append(indentString(childIndent))
            result.append("\(key):")

            switch value.rawValue {
            case .object, .array:
                serializeNode(value, indent: childIndent, isRoot: false, result: &result)
            case .null:
                result.append(" null")
                writeInlineComment(value.inlineComment, to: &result)
            case .bool(let v):
                result.append(" \(v ? "true" : "false")")
                writeInlineComment(value.inlineComment, to: &result)
            case .number(let v):
                result.append(" \(v)")
                writeInlineComment(value.inlineComment, to: &result)
            case .string(let str):
                if str.contains("\n") {
                    result.append(" |\n")
                    let lines = str.components(separatedBy: .newlines)
                    for line in lines {
                        result.append(indentString(childIndent + indentCount))
                        result.append(line)
                        result.append("\n")
                    }
                } else if needsDoubleQuotes(str) {
                    result.append(" \"\(escapeString(str))\"")
                    writeInlineComment(value.inlineComment, to: &result)
                } else {
                    result.append(" \(str)")
                    writeInlineComment(value.inlineComment, to: &result)
                }
            case .error:
                result.append(" null")
            }
        }
    }

    // MARK: - 注释输出

    /// 输出前导注释行（多行保持原格式）
    private func writeLeadingComments(_ comments: [String], indent: Int, to result: inout String) {
        guard includeComments else { return }
        for comment in comments {
            result.append(indentString(indent))
            result.append("# \(comment)\n")
        }
    }

    /// 输出内联注释（在同一行末尾）
    private func writeInlineComment(_ comment: String?, to result: inout String) {
        if let comment, includeComments {
            result.append(" # \(comment)\n")
        } else {
            result.append("\n")
        }
    }

    /// 生成缩进字符串
    private func indentString(_ count: Int) -> String {
        guard count > 0 else { return "" }
        return String(repeating: " ", count: count)
    }
}

// MARK: - Node.Value 辅助

extension Node.Value {
    /// 安全获取数组值
    var arrayValue: [Node]? {
        if case .array(let items) = self { return items }
        return nil
    }
}
