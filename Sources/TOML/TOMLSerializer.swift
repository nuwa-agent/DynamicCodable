//
//  TOMLSerializer.swift
//  Nuwa
//

import Foundation
import DynamicCodable

public struct TOMLSerializer {

    /// 是否输出注释，默认 true
    public var includeComments: Bool

    public init(includeComments: Bool = true) {
        self.includeComments = includeComments
    }

    public func serialize(_ node: Node) -> String {
        var result = ""
        serializeRoot(node, result: &result)
        return result
    }

    // MARK: - 根节点序列化

    private func serializeRoot(_ node: Node, result: inout String) {
        guard case .object(let dict) = node.rawValue else {
            serializeValue(node, result: &result)
            result.append("\n")
            return
        }
        // 输出根节点之前的注释
        writeLeadingComments(node.comments, to: &result)
        // 分离出标量键值对、子表、表数组
        var scalars: OrderedDictionary<String, Node> = [:]
        var tables: OrderedDictionary<String, Node> = [:]
        var arrayTables: OrderedDictionary<String, Node> = [:]
        for (key, value) in dict {
            switch value.rawValue {
            case .object:
                tables[key] = value
            case .array(let items):
                // 判断是否为表数组（数组中所有元素都是 object）
                if items.allSatisfy({ if case .object = $0.rawValue { return true }; return false }) {
                    arrayTables[key] = value
                } else {
                    scalars[key] = value
                }
            default:
                scalars[key] = value
            }
        }
        // 输出标量键值对
        var isFirst = true
        for (key, value) in scalars {
            if !isFirst || !result.isEmpty {
                result.append("\n")
            }
            isFirst = false
            serializeKeyValue(key: key, value: value, result: &result)
        }
        // 输出子表 [key]
        for (key, value) in tables {
            // 插入注释前补充空行分隔
            if !result.isEmpty && !result.hasSuffix("\n\n") {
                result.append("\n")
            }
            writeLeadingComments(value.comments, to: &result)
            result.append("[\(key)]\n")
            serializeInline(key: key, value: value, prefix: key, result: &result)
        }
        // 输出表数组 [[key]]
        for (key, value) in arrayTables {
            guard case .array(let items) = value.rawValue else { continue }
            for item in items {
                if !result.isEmpty && !result.hasSuffix("\n\n") {
                    result.append("\n")
                }
                writeLeadingComments(item.comments, to: &result)
                result.append("[[\(key)]]\n")
                serializeInline(key: key, value: item, prefix: key, result: &result)
            }
        }
    }

    // MARK: - 内联表/子表内容序列化

    private func serializeInline(key: String, value: Node, prefix: String, result: inout String) {
        guard case .object(let dict) = value.rawValue else { return }
        // 分离标量和子表
        var scalars: OrderedDictionary<String, Node> = [:]
        var subTables: OrderedDictionary<String, Node> = [:]
        var subArrayTables: OrderedDictionary<String, Node> = [:]
        for (k, v) in dict {
            switch v.rawValue {
            case .object:
                subTables[k] = v
            case .array(let items):
                if items.allSatisfy({ if case .object = $0.rawValue { return true }; return false }) {
                    subArrayTables[k] = v
                } else {
                    scalars[k] = v
                }
            default:
                scalars[k] = v
            }
        }
        // 输出标量
        for (k, v) in scalars {
            serializeKeyValue(key: k, value: v, result: &result)
        }
        // 输出子表 [parent.child]
        for (k, v) in subTables {
            if !result.hasSuffix("\n\n") {
                result.append("\n")
            }
            writeLeadingComments(v.comments, to: &result)
            let fullPath = "\(prefix).\(k)"
            result.append("[\(fullPath)]\n")
            serializeInline(key: k, value: v, prefix: fullPath, result: &result)
        }
        // 输出表数组 [[parent.child]]
        for (k, v) in subArrayTables {
            guard case .array(let items) = v.rawValue else { continue }
            let fullPath = "\(prefix).\(k)"
            for item in items {
                if !result.hasSuffix("\n\n") {
                    result.append("\n")
                }
                writeLeadingComments(item.comments, to: &result)
                result.append("[[\(fullPath)]]\n")
                serializeInline(key: k, value: item, prefix: fullPath, result: &result)
            }
        }
    }

    // MARK: - 键值对序列化

    private func serializeKeyValue(key: String, value: Node, result: inout String) {
        // 输出前导注释
        writeLeadingComments(value.comments, to: &result)
        result.append("\(key) = ")
        serializeValue(value, result: &result)
        // 输出内联注释
        if let ic = value.inlineComment, includeComments {
            result.append(" # \(ic)")
        }
        result.append("\n")
    }

    // MARK: - 值序列化

    private func serializeValue(_ node: Node, result: inout String) {
        switch node.rawValue {
        case .null:
            result.append("")
        case .bool(let v):
            result.append(v ? "true" : "false")
        case .number(let v):
            result.append(v)
        case .string(let v):
            serializeString(v, result: &result)
        case .array(let items):
            serializeArray(items, result: &result)
        case .object(let dict):
            serializeInlineTable(dict, result: &result)
        case .error:
            result.append("")
        }
    }

    // MARK: - 字符串序列化

    private func serializeString(_ str: String, result: inout String) {
        // 判断是否使用多行字符串
        if str.contains("\n") {
            // 多行基本字符串 """
            result.append("\"\"\"\n")
            result.append(str)
            result.append("\n\"\"\"")
            return
        }
        // 判断是否需要引号（TOML 中字符串值必须用引号）
        // TOML 字符串可以是基本字符串 "" 或纯字符串 ''
        // 此处优先使用基本字符串，转义特殊字符
        let escaped = escapeTOMLString(str)
        result.append("\"\(escaped)\"")
    }

    private func escapeTOMLString(_ str: String) -> String {
        var result = ""
        for char in str {
            switch char {
            case "\\": result.append("\\\\")
            case "\"": result.append("\\\"")
            case "\n": result.append("\\n")
            case "\t": result.append("\\t")
            case "\r": result.append("\\r")
            case "\u{0008}": result.append("\\b")
            case "\u{000C}": result.append("\\f")
            default: result.append(char)
            }
        }
        return result
    }

    // MARK: - 数组序列化

    private func serializeArray(_ items: [Node], result: inout String) {
        if items.isEmpty {
            result.append("[]")
            return
        }
        // 检查是否全部为简单标量（单行可显示）
        if items.allSatisfy({ isSimpleScalar($0) }) {
            result.append("[")
            for (i, item) in items.enumerated() {
                if i > 0 { result.append(", ") }
                serializeValue(item, result: &result)
            }
            result.append("]")
        } else {
            // 多行数组
            result.append("[\n")
            for item in items {
                writeLeadingComments(item.comments, to: &result)
                result.append("  ")
                serializeValue(item, result: &result)
                result.append(",\n")
            }
            result.append("]")
        }
    }

    private func isSimpleScalar(_ node: Node) -> Bool {
        switch node.rawValue {
        case .null, .bool, .number, .string: return true
        default: return false
        }
    }

    // MARK: - 内联表序列化

    private func serializeInlineTable(_ dict: OrderedDictionary<String, Node>, result: inout String) {
        if dict.isEmpty {
            result.append("{}")
            return
        }
        result.append("{ ")
        var first = true
        for (key, value) in dict {
            if !first { result.append(", ") }
            first = false
            result.append("\(key) = ")
            serializeValue(value, result: &result)
        }
        result.append(" }")
    }

    // MARK: - 注释输出

    private func writeLeadingComments(_ comments: [String], to result: inout String) {
        guard includeComments else { return }
        for comment in comments {
            result.append("# \(comment)\n")
        }
    }
}
