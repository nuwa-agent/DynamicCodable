//
//  Json+Schema.swift
//  DynamicCodable
//
//  Created by yNasMac on 2026/5/31.
//

import Foundation
import DynamicCodable

public enum Json {}

// MARK: - Schema

extension Json {

    public indirect enum Schema: Sendable {
        case array(
            items: Schema,
            minItems: Int? = nil,
            maxItems: Int? = nil
        )
        case object(
            properties: OrderedDictionary<String, Json.Schema>,
            required: [String] = []
        )
        case string(
            description: String,
            `enum`: [String] = [],
            minLength: Int? = nil,
            maxLength: Int? = nil,
            pattern: String? = nil
        )
        case number(
            description: String,
            `enum`: [Double] = [],
            minimum: Double? = nil,
            maximum: Double? = nil
        )
        case integer(
            description: String,
            `enum`: [Int] = [],
            minimum: Int? = nil,
            maximum: Int? = nil
        )
        case boolean(
            description: String
        )
    }
}

// MARK: - Transform

extension Json.Schema {

    public static func string<S>(description: String, `enum`: [S] = []) -> Json.Schema where S: RawRepresentable, S.RawValue == String {
        .string(description: description, enum: `enum`.map(\.rawValue))
    }
    public static func number<S>(description: String, `enum`: [S] = []) -> Json.Schema where S: RawRepresentable, S.RawValue: BinaryFloatingPoint {
        .number(description: description, enum: `enum`.map({ Double($0.rawValue) }))
    }
    public static func integer<S>(description: String, `enum`: [S] = []) -> Json.Schema where S: RawRepresentable, S.RawValue: BinaryInteger {
        .integer(description: description, enum: `enum`.map({ Int(truncatingIfNeeded: $0.rawValue) }))
    }

}

// MARK: - Codable

extension Json.Schema: Codable {

    private enum CodingKeys: String, CodingKey {
        case type, description, properties, required, items, `enum`
        case minLength, maxLength, pattern
        case minimum, maximum
        case minItems, maxItems
    }

    // ─── Encode ───

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .array(items, minItems, maxItems):
            try container.encode("array",    forKey: .type)
            try container.encode(items,      forKey: .items)
            try container.encodeIfPresent(minItems, forKey: .minItems)
            try container.encodeIfPresent(maxItems, forKey: .maxItems)

        case let .object(props, req):
            try container.encode("object",   forKey: .type)
            try container.encode(props,      forKey: .properties)
            if !req.isEmpty {
                try container.encode(req,    forKey: .required)
            }

        case let .string(desc, values, minLength, maxLength, pattern):
            try container.encode("string",   forKey: .type)
            try container.encode(desc,       forKey: .description)
            if !values.isEmpty {
                try container.encode(values, forKey: .enum)
            }
            try container.encodeIfPresent(minLength, forKey: .minLength)
            try container.encodeIfPresent(maxLength, forKey: .maxLength)
            try container.encodeIfPresent(pattern,   forKey: .pattern)

        case let .number(desc, values, minimum, maximum):
            try container.encode("number",   forKey: .type)
            try container.encode(desc,       forKey: .description)
            if !values.isEmpty {
                try container.encode(values, forKey: .enum)
            }
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)

        case let .integer(desc, values, minimum, maximum):
            try container.encode("integer",  forKey: .type)
            try container.encode(desc,       forKey: .description)
            if !values.isEmpty {
                try container.encode(values, forKey: .enum)
            }
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)

        case let .boolean(desc):
            try container.encode("boolean",  forKey: .type)
            try container.encode(desc,       forKey: .description)
        }
    }

    // ─── Decode ───

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let desc = try container.decodeIfPresent(String.self, forKey: .description) ?? ""

        switch type {
        case "array":
            let items = try container.decode(Json.Schema.self, forKey: .items)
            let minItems = try container.decodeIfPresent(Int.self, forKey: .minItems)
            let maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems)
            self = .array(items: items, minItems: minItems, maxItems: maxItems)

        case "object":
            let props = try container.decode(
                OrderedDictionary<String, Json.Schema>.self, forKey: .properties
            )
            let req = try container.decodeIfPresent([String].self, forKey: .required) ?? []
            self = .object(properties: props, required: req)

        case "string":
            let values = try container.decodeIfPresent([String].self, forKey: .enum) ?? []
            let minLength = try container.decodeIfPresent(Int.self, forKey: .minLength)
            let maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
            let pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
            self = .string(description: desc, enum: values, minLength: minLength, maxLength: maxLength, pattern: pattern)

        case "number":
            let values = try container.decodeIfPresent([Double].self, forKey: .enum) ?? []
            let minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
            let maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
            self = .number(description: desc, enum: values, minimum: minimum, maximum: maximum)

        case "integer":
            let values = try container.decodeIfPresent([Int].self, forKey: .enum) ?? []
            let minimum = try container.decodeIfPresent(Int.self, forKey: .minimum)
            let maximum = try container.decodeIfPresent(Int.self, forKey: .maximum)
            self = .integer(description: desc, enum: values, minimum: minimum, maximum: maximum)

        case "boolean":
            self = .boolean(description: desc)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unsupported schema type: \(type)"
            )
        }
    }
}

// MARK: - Node.Convertible
extension Json.Schema: Node.Convertible {
    public var asNode: Node {
        switch self {
        case let .array(items, minItems, maxItems):
            var dict: OrderedDictionary<String, Node> = [
                "type"          : .string("array"),
                "items"         : items.asNode,
            ]
            if let minItems { dict["minItems"] = .int(minItems) }
            if let maxItems { dict["maxItems"] = .int(maxItems) }
            return .object(dict)
        case let .object(props, req):
            var dict: OrderedDictionary<String, Node> = [
                "type"          : .string("object"),
                "properties"    : .object(props.mapValues(\.asNode)),
            ]
            if !req.isEmpty {
                dict["required"] = .array(req.map(\.asNode))
            }
            return .object(dict)
        case let .string(desc, values, minLength, maxLength, pattern):
            var dict: OrderedDictionary<String, Node> = [
                "type"          : .string("string"),
                "description"   : .string(desc),
            ]
            if !values.isEmpty {
                dict["enum"] = .array(values.map(\.asNode))
            }
            if let minLength { dict["minLength"] = .integer(minLength) }
            if let maxLength { dict["maxLength"] = .integer(maxLength) }
            if let pattern, !pattern.isEmpty { dict["pattern"] = .string(pattern) }
            return .object(dict)
        case let .number(desc, values, minimum, maximum):
            var dict: OrderedDictionary<String, Node> = [
                "type"          : .string("number"),
                "description"   : .string(desc),
            ]
            if !values.isEmpty {
                dict["enum"] = .array(values.map(\.asNode))
            }
            if let minimum { dict["minimum"] = .number(minimum) }
            if let maximum { dict["maximum"] = .number(maximum) }
            return .object(dict)
        case let .integer(desc, values, minimum, maximum):
            var dict: OrderedDictionary<String, Node> = [
                "type"          : .string("integer"),
                "description"   : .string(desc),
            ]
            if !values.isEmpty {
                dict["enum"] = .array(values.map(\.asNode))
            }
            if let minimum { dict["minimum"] = .integer(minimum) }
            if let maximum { dict["maximum"] = .integer(maximum) }
            return .object(dict)
        case .boolean(let desc):
            return .object([
                "type"          : .string("boolean"),
                "description"   : .string(desc),
            ])
        }
    }
}

// MARK: - Validation

extension Json.Schema {

    /// Schema 校验错误类型，描述 Node 数据不匹配 Schema 的具体原因
    public enum ValidationError: LocalizedError, CustomStringConvertible {
        /// 类型不匹配
        case typeMismatch(expected: String, actual: String, at: String)
        /// 必填字段缺失
        case missingRequired(field: String, at: String)
        /// 值不在枚举范围内
        case valueNotInEnum(field: String, allowed: [String], actual: String, at: String)
        /// 值超出范围约束
        case valueOutOfRange(field: String, range: String, actual: String, at: String)
        /// 字符串长度低于最小值
        case stringTooShort(field: String, minLength: Int, actualLength: Int, at: String)
        /// 字符串长度超出最大值
        case stringTooLong(field: String, maxLength: Int, actualLength: Int, at: String)
        /// 字符串不匹配正则模式
        case stringPatternMismatch(field: String, pattern: String, actual: String, at: String)
        /// 数组元素数量低于最小值
        case arrayTooShort(field: String, minItems: Int, actualCount: Int, at: String)
        /// 数组元素数量超出最大值
        case arrayTooLong(field: String, maxItems: Int, actualCount: Int, at: String)

        public var description: String {
            switch self {
            case let .typeMismatch(expected, actual, path):
                return "[\(path)] 期望类型为 \(expected)，实际为 \(actual)"
            case let .missingRequired(field, path):
                return "[\(path)] 必填字段 \"\(field)\" 缺失"
            case let .valueNotInEnum(field, allowed, actual, path):
                return "[\(path)] 字段 \"\(field)\" 值 \"\(actual)\" 不在允许值 \(allowed) 中"
            case let .valueOutOfRange(field, range, actual, path):
                return "[\(path)] 字段 \"\(field)\" 值 \(actual) 超出范围 \(range)"
            case let .stringTooShort(field, minLength, actualLength, path):
                return "[\(path)] 字段 \"\(field)\" 最少 \(minLength) 字符，实际 \(actualLength)"
            case let .stringTooLong(field, maxLength, actualLength, path):
                return "[\(path)] 字段 \"\(field)\" 最多 \(maxLength) 字符，实际 \(actualLength)"
            case let .stringPatternMismatch(field, pattern, actual, path):
                return "[\(path)] 字段 \"\(field)\" 值 \"\(actual)\" 不匹配正则 \(pattern)"
            case let .arrayTooShort(field, minItems, actualCount, path):
                return "[\(path)] 字段 \"\(field)\" 最少 \(minItems) 个元素，实际 \(actualCount)"
            case let .arrayTooLong(field, maxItems, actualCount, path):
                return "[\(path)] 字段 \"\(field)\" 最多 \(maxItems) 个元素，实际 \(actualCount)"
            }
        }
        
        public var errorDescription: String? {
            return description
        }
    }

    /// 校验 Node 数据是否符合当前 Schema 定义
    ///
    /// - Parameters:
    ///   - node: 待校验的 Node 数据
    ///   - path: 当前校验路径（用于错误定位，支持 JSON Path 格式如 "$.user.name"）
    /// - Throws: ``ValidationError`` 如果数据不匹配 Schema
    public func validate(_ node: Node, at path: String = "$") throws {
        // 简写别名，避免在 throw 中重复写完整类型路径
        typealias E = Json.Schema.ValidationError

        switch self {

        // ── 对象类型校验：检查必填字段 + 递归校验每个属性 ──
        case let .object(properties, required):
            guard case .object(let dict) = node.rawValue else {
                throw E.typeMismatch(expected: "object", actual: node.rawValue.typeName, at: path)
            }
            // 校验所有必填字段是否存在
            for field in required {
                guard dict[field] != nil else {
                    throw E.missingRequired(field: field, at: "\(path).\(field)")
                }
            }
            // 递归校验已提供的属性值是否符合各自 Schema
            for (key, schema) in properties {
                if let value = dict[key] {
                    try schema.validate(value, at: "\(path).\(key)")
                }
            }

        // ── 字符串类型校验：类型 + 枚举 + 长度 + 正则 ──
        case let .string(_, enumValues, minLength, maxLength, pattern):
            guard case .string(let str) = node.rawValue else {
                throw E.typeMismatch(expected: "string", actual: node.rawValue.typeName, at: path)
            }
            // 校验枚举值约束
            if !enumValues.isEmpty, !enumValues.contains(str) {
                throw E.valueNotInEnum(field: path, allowed: enumValues, actual: str, at: path)
            }
            // 校验最小长度
            if let minimumLength = minLength, str.count < minimumLength {
                throw E.stringTooShort(field: path, minLength: minimumLength, actualLength: str.count, at: path)
            }
            // 校验最大长度
            if let maximumLength = maxLength, str.count > maximumLength {
                throw E.stringTooLong(field: path, maxLength: maximumLength, actualLength: str.count, at: path)
            }
            // 校验正则模式
            if let regexPattern = pattern, str.range(of: regexPattern, options: .regularExpression) == nil {
                throw E.stringPatternMismatch(field: path, pattern: regexPattern, actual: str, at: path)
            }

        // ── 浮点数类型校验：类型 + 枚举 + 范围 ──
        case let .number(_, enumValues, minVal, maxVal):
            guard case .number(let numStr) = node.rawValue,
                  let num = Double(numStr) else {
                throw E.typeMismatch(expected: "number", actual: node.rawValue.typeName, at: path)
            }
            // 校验枚举值约束
            if !enumValues.isEmpty, !enumValues.contains(num) {
                throw E.valueNotInEnum(
                    field: path,
                    allowed: enumValues.map { String($0) },
                    actual: String(num),
                    at: path
                )
            }
            // 校验最小值
            if let minimum = minVal, num < minimum {
                throw E.valueOutOfRange(field: path, range: ">= \(minimum)", actual: String(num), at: path)
            }
            // 校验最大值
            if let maximum = maxVal, num > maximum {
                throw E.valueOutOfRange(field: path, range: "<= \(maximum)", actual: String(num), at: path)
            }

        // ── 整数类型校验：类型 + 枚举 + 范围 ──
        case let .integer(_, enumValues, minVal, maxVal):
            // JSON 中整数也存储为 .number，需要额外检查是否为整数值
            guard case .number(let numStr) = node.rawValue,
                  let num = Int(numStr) else {
                throw E.typeMismatch(expected: "integer", actual: node.rawValue.typeName, at: path)
            }
            // 校验枚举值约束
            if !enumValues.isEmpty, !enumValues.contains(num) {
                throw E.valueNotInEnum(
                    field: path,
                    allowed: enumValues.map { String($0) },
                    actual: String(num),
                    at: path
                )
            }
            // 校验最小值
            if let minimum = minVal, num < minimum {
                throw E.valueOutOfRange(field: path, range: ">= \(minimum)", actual: String(num), at: path)
            }
            // 校验最大值
            if let maximum = maxVal, num > maximum {
                throw E.valueOutOfRange(field: path, range: "<= \(maximum)", actual: String(num), at: path)
            }

        // ── 布尔类型校验 ──
        case .boolean(_):
            guard case .bool(_) = node.rawValue else {
                throw E.typeMismatch(expected: "boolean", actual: node.rawValue.typeName, at: path)
            }

        // ── 数组类型校验：类型 + 长度 + 递归校验每个元素 ──
        case let .array(items, minimumItems, maximumItems):
            guard case .array(let arr) = node.rawValue else {
                throw E.typeMismatch(expected: "array", actual: node.rawValue.typeName, at: path)
            }
            // 校验最小元素数
            if let minItems = minimumItems, arr.count < minItems {
                throw E.arrayTooShort(field: path, minItems: minItems, actualCount: arr.count, at: path)
            }
            // 校验最大元素数
            if let maxItems = maximumItems, arr.count > maxItems {
                throw E.arrayTooLong(field: path, maxItems: maxItems, actualCount: arr.count, at: path)
            }
            // 递归校验每个元素
            for (index, item) in arr.enumerated() {
                try items.validate(item, at: "\(path)[\(index)]")
            }
        }
    }
}

// MARK: - Node.Value typeName

extension Node.Value {
    /// 返回人类可读的类型名称，用于校验错误信息
    var typeName: String {
        switch self {
        case .null:    return "null"
        case .bool:    return "boolean"
        case .number:  return "number"
        case .string:  return "string"
        case .array:   return "array"
        case .object:  return "object"
        case .error:   return "error"
        }
    }
}

// MARK: - Tool

extension Json {

    public struct Tool: Codable, Sendable {
        public let type: String
        public let function: Function

        public init(name: String, description: String, parameters: Json.Schema) {
            self.type = "function"
            self.function = Function(
                name: name,
                description: description,
                parameters: parameters
            )
        }
    }
}

extension Json.Tool {

    public struct Function: Codable, Sendable {
        public let name: String
        public let description: String
        public let parameters: Json.Schema
    }
}

extension Json.Tool.Function: Node.Convertible {
    public var asNode: Node {
        .object([
            "name"          : .string(name),
            "description"   : .string(description),
            "parameters"    : parameters.asNode,
        ])
    }
}

extension Json.Tool: Node.Convertible {
    public var asNode: Node {
        .object([
            "type"      : .string("function"),
            "function"  : function.asNode
        ])
    }
}
