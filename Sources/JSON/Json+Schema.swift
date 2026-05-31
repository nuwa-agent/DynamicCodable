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
            if let minLength { dict["minLength"] = .int(minLength) }
            if let maxLength { dict["maxLength"] = .int(maxLength) }
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
            if let minimum { dict["minimum"] = .double(minimum) }
            if let maximum { dict["maximum"] = .double(maximum) }
            return .object(dict)
        case let .integer(desc, values, minimum, maximum):
            var dict: OrderedDictionary<String, Node> = [
                "type"          : .string("integer"),
                "description"   : .string(desc),
            ]
            if !values.isEmpty {
                dict["enum"] = .array(values.map(\.asNode))
            }
            if let minimum { dict["minimum"] = .int(minimum) }
            if let maximum { dict["maximum"] = .int(maximum) }
            return .object(dict)
        case .boolean(let desc):
            return .object([
                "type"          : .string("boolean"),
                "description"   : .string(desc),
            ])
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
