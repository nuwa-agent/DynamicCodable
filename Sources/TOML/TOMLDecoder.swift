//
//  TOMLDecoder.swift
//  Nuwa
//

import Foundation
import DynamicCodable

public struct TOMLDecoder {

    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    public func decode<T: Decodable>(_ type: T.Type, from toml: String) throws -> T {
        if type == Node.self {
            var parser = TOMLParser()
            let node = try parser.parse(toml)
            return node as! T
        }
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        let decoder = _TOMLDecoder(node: node, userInfo: userInfo, codingPath: [])
        return try T(from: decoder)
    }
}

// MARK: - 内部 Decoder

private class _TOMLDecoder: Decoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    let node: Node

    init(node: Node, userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey]) {
        self.node = node
        self.userInfo = userInfo
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .object(let dict) = node.rawValue else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "期望对象类型，实际为: \(node.rawValue)")
            )
        }
        let container = _TOMLKeyedDecodingContainer<Key>(dict: dict, decoder: self, codingPath: codingPath)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let items) = node.rawValue else {
            throw DecodingError.typeMismatch(
                [Any].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "期望数组类型，实际为: \(node.rawValue)")
            )
        }
        return _TOMLUnkeyedDecodingContainer(items: items, decoder: self, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return _TOMLSingleValueDecodingContainer(node: node, decoder: self, codingPath: codingPath)
    }
}

// MARK: - 键容器

private struct _TOMLKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let dict: OrderedDictionary<String, Node>
    let decoder: _TOMLDecoder
    var codingPath: [CodingKey]

    var allKeys: [Key] { dict.keys.compactMap { Key(stringValue: $0) } }

    func contains(_ key: Key) -> Bool { dict.keys.contains(key.stringValue) }

    private func node(forKey key: Key) throws -> Node {
        guard let node = dict[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "未找到键: \(key.stringValue)"))
        }
        return node
    }

    private func decoderForNode(_ node: Node, key: CodingKey) -> _TOMLDecoder {
        _TOMLDecoder(node: node, userInfo: decoder.userInfo, codingPath: codingPath + [key])
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let node = dict[key.stringValue] else { return true }
        if case .null = node.rawValue { return true }
        return false
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let node = try self.node(forKey: key)
        switch node.rawValue {
        case .bool(let v): return v
        case .string(let v):
            switch v.lowercased() {
            case "true", "yes", "on": return true
            case "false", "no", "off": return false
            default: break
            }
        default: break
        }
        throw typeMismatch(type, forKey: key, node: node)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let node = try self.node(forKey: key)
        switch node.rawValue {
        case .string(let v): return v
        case .number(let v): return v
        case .bool(let v): return v ? "true" : "false"
        default: break
        }
        throw typeMismatch(type, forKey: key, node: node)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let node = try self.node(forKey: key)
        return try decodeDouble(node: node, forKey: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        Float(try decode(Double.self, forKey: key))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let node = try self.node(forKey: key)
        return try decodeInt(node: node, forKey: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { Int8(truncatingIfNeeded: try decode(Int.self, forKey: key)) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { Int16(truncatingIfNeeded: try decode(Int.self, forKey: key)) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { Int32(truncatingIfNeeded: try decode(Int.self, forKey: key)) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { let node = try self.node(forKey: key); return try decodeInt64(node: node, forKey: key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { let node = try self.node(forKey: key); return try decodeUInt(node: node, forKey: key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { UInt8(truncatingIfNeeded: try decode(UInt.self, forKey: key)) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { UInt16(truncatingIfNeeded: try decode(UInt.self, forKey: key)) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { UInt32(truncatingIfNeeded: try decode(UInt.self, forKey: key)) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { let node = try self.node(forKey: key); return try decodeUInt64(node: node, forKey: key) }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let node = try self.node(forKey: key)
        if type == Bool.self { return try decode(Bool.self, forKey: key) as! T }
        if type == String.self { return try decode(String.self, forKey: key) as! T }
        if type == Double.self { return try decode(Double.self, forKey: key) as! T }
        if type == Float.self { return try decode(Float.self, forKey: key) as! T }
        if type == Int.self { return try decode(Int.self, forKey: key) as! T }
        if type == Int8.self { return try decode(Int8.self, forKey: key) as! T }
        if type == Int16.self { return try decode(Int16.self, forKey: key) as! T }
        if type == Int32.self { return try decode(Int32.self, forKey: key) as! T }
        if type == Int64.self { return try decode(Int64.self, forKey: key) as! T }
        if type == UInt.self { return try decode(UInt.self, forKey: key) as! T }
        if type == UInt8.self { return try decode(UInt8.self, forKey: key) as! T }
        if type == UInt16.self { return try decode(UInt16.self, forKey: key) as! T }
        if type == UInt32.self { return try decode(UInt32.self, forKey: key) as! T }
        if type == UInt64.self { return try decode(UInt64.self, forKey: key) as! T }
        let child = decoderForNode(node, key: key)
        return try T(from: child)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let node = try self.node(forKey: key)
        let child = decoderForNode(node, key: key)
        return try child.container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let node = try self.node(forKey: key)
        let child = decoderForNode(node, key: key)
        return try child.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder { decoder }
    func superDecoder(forKey key: Key) throws -> Decoder {
        let node = try self.node(forKey: key)
        return decoderForNode(node, key: key)
    }

    private func typeMismatch(_ type: Any.Type, forKey key: Key, node: Node) -> DecodingError {
        DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "期望 \(type)，实际为: \(node.rawValue)"))
    }

    private func decodeDouble(node: Node, forKey key: Key) throws -> Double {
        switch node.rawValue {
        case .number(let v): if let d = Double(v) { return d }
        case .string(let v): if let d = Double(v) { return d }
        case .bool(let v): return v ? 1.0 : 0.0
        default: break
        }
        throw typeMismatch(Double.self, forKey: key, node: node)
    }

    private func decodeInt(node: Node, forKey key: Key) throws -> Int {
        switch node.rawValue {
        case .number(let v): if let i = Int(v) { return i }
        case .string(let v): if let i = Int(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(Int.self, forKey: key, node: node)
    }

    private func decodeInt64(node: Node, forKey key: Key) throws -> Int64 {
        switch node.rawValue {
        case .number(let v): if let i = Int64(v) { return i }
        case .string(let v): if let i = Int64(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(Int64.self, forKey: key, node: node)
    }

    private func decodeUInt(node: Node, forKey key: Key) throws -> UInt {
        switch node.rawValue {
        case .number(let v): if let i = UInt(v) { return i }
        case .string(let v): if let i = UInt(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(UInt.self, forKey: key, node: node)
    }

    private func decodeUInt64(node: Node, forKey key: Key) throws -> UInt64 {
        switch node.rawValue {
        case .number(let v): if let i = UInt64(v) { return i }
        case .string(let v): if let i = UInt64(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(UInt64.self, forKey: key, node: node)
    }
}

// MARK: - 无键容器

private struct _TOMLUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let items: [Node]
    let decoder: _TOMLDecoder
    var codingPath: [CodingKey]
    var currentIndex: Int = 0
    var count: Int? { items.count }
    var isAtEnd: Bool { currentIndex >= items.count }
    private var currentItem: Node { items[currentIndex] }
    private mutating func advance() { currentIndex += 1 }

    private func childDecoder(for node: Node) -> _TOMLDecoder {
        let key = _TOMLCodingKey(index: currentIndex)
        return _TOMLDecoder(node: node, userInfo: decoder.userInfo, codingPath: codingPath + [key])
    }

    private func typeMismatchError(_ type: Any.Type) -> DecodingError {
        let key = _TOMLCodingKey(index: currentIndex)
        return DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "期望 \(type)，实际为: \(currentItem.rawValue)"))
    }

    mutating func decodeNil() throws -> Bool {
        if case .null = currentItem.rawValue { advance(); return true }
        return false
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        defer { advance() }
        switch currentItem.rawValue {
        case .bool(let v): return v
        case .string(let v):
            switch v.lowercased() {
            case "true", "yes", "on": return true
            case "false", "no", "off": return false
            default: break
            }
        default: break
        }
        throw typeMismatchError(type)
    }

    mutating func decode(_ type: String.Type) throws -> String {
        defer { advance() }
        switch currentItem.rawValue {
        case .string(let v): return v
        case .number(let v): return v
        case .bool(let v): return v ? "true" : "false"
        default: break
        }
        throw typeMismatchError(type)
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        defer { advance() }
        switch currentItem.rawValue {
        case .number(let v): if let d = Double(v) { return d }
        case .string(let v): if let d = Double(v) { return d }
        case .bool(let v): return v ? 1.0 : 0.0
        default: break
        }
        throw typeMismatchError(type)
    }

    mutating func decode(_ type: Float.Type) throws -> Float { Float(try decode(Double.self)) }
    mutating func decode(_ type: Int.Type) throws -> Int {
        defer { advance() }
        switch currentItem.rawValue {
        case .number(let v): if let i = Int(v) { return i }
        case .string(let v): if let i = Int(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatchError(type)
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 { Int8(truncatingIfNeeded: try decode(Int.self)) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { Int16(truncatingIfNeeded: try decode(Int.self)) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { Int32(truncatingIfNeeded: try decode(Int.self)) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        defer { advance() }
        switch currentItem.rawValue {
        case .number(let v): if let i = Int64(v) { return i }
        case .string(let v): if let i = Int64(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatchError(type)
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        defer { advance() }
        switch currentItem.rawValue {
        case .number(let v): if let i = UInt(v) { return i }
        case .string(let v): if let i = UInt(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatchError(type)
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { UInt8(truncatingIfNeeded: try decode(UInt.self)) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { UInt16(truncatingIfNeeded: try decode(UInt.self)) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { UInt32(truncatingIfNeeded: try decode(UInt.self)) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        defer { advance() }
        switch currentItem.rawValue {
        case .number(let v): if let i = UInt64(v) { return i }
        case .string(let v): if let i = UInt64(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatchError(type)
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        defer { advance() }
        if type == Bool.self { return try decode(Bool.self) as! T }
        if type == String.self { return try decode(String.self) as! T }
        if type == Double.self { return try decode(Double.self) as! T }
        if type == Float.self { return try decode(Float.self) as! T }
        if type == Int.self { return try decode(Int.self) as! T }
        if type == Int64.self { return try decode(Int64.self) as! T }
        if type == UInt.self { return try decode(UInt.self) as! T }
        if type == UInt64.self { return try decode(UInt64.self) as! T }
        let child = childDecoder(for: currentItem)
        return try T(from: child)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        defer { advance() }
        let child = childDecoder(for: currentItem)
        return try child.container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        defer { advance() }
        let child = childDecoder(for: currentItem)
        return try child.unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        defer { advance() }
        return childDecoder(for: currentItem)
    }
}

// MARK: - 单值容器

private struct _TOMLSingleValueDecodingContainer: SingleValueDecodingContainer {
    let node: Node
    let decoder: _TOMLDecoder
    var codingPath: [CodingKey]

    func decodeNil() -> Bool { if case .null = node.rawValue { return true }; return false }

    func decode(_ type: Bool.Type) throws -> Bool {
        switch node.rawValue {
        case .bool(let v): return v
        case .string(let v):
            switch v.lowercased() {
            case "true", "yes", "on": return true
            case "false", "no", "off": return false
            default: break
            }
        default: break
        }
        throw typeMismatch(type)
    }

    func decode(_ type: String.Type) throws -> String {
        switch node.rawValue {
        case .string(let v): return v
        case .number(let v): return v
        case .bool(let v): return v ? "true" : "false"
        default: break
        }
        throw typeMismatch(type)
    }

    func decode(_ type: Double.Type) throws -> Double {
        switch node.rawValue {
        case .number(let v): if let d = Double(v) { return d }
        case .string(let v): if let d = Double(v) { return d }
        case .bool(let v): return v ? 1.0 : 0.0
        default: break
        }
        throw typeMismatch(type)
    }

    func decode(_ type: Float.Type) throws -> Float { Float(try decode(Double.self)) }

    func decode(_ type: Int.Type) throws -> Int {
        switch node.rawValue {
        case .number(let v): if let i = Int(v) { return i }
        case .string(let v): if let i = Int(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(type)
    }

    func decode(_ type: Int8.Type) throws -> Int8 { Int8(truncatingIfNeeded: try decode(Int.self)) }
    func decode(_ type: Int16.Type) throws -> Int16 { Int16(truncatingIfNeeded: try decode(Int.self)) }
    func decode(_ type: Int32.Type) throws -> Int32 { Int32(truncatingIfNeeded: try decode(Int.self)) }
    func decode(_ type: Int64.Type) throws -> Int64 {
        switch node.rawValue {
        case .number(let v): if let i = Int64(v) { return i }
        case .string(let v): if let i = Int64(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(type)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        switch node.rawValue {
        case .number(let v): if let i = UInt(v) { return i }
        case .string(let v): if let i = UInt(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(type)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 { UInt8(truncatingIfNeeded: try decode(UInt.self)) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { UInt16(truncatingIfNeeded: try decode(UInt.self)) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { UInt32(truncatingIfNeeded: try decode(UInt.self)) }
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        switch node.rawValue {
        case .number(let v): if let i = UInt64(v) { return i }
        case .string(let v): if let i = UInt64(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(type)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if type == Bool.self { return try decode(Bool.self) as! T }
        if type == String.self { return try decode(String.self) as! T }
        if type == Double.self { return try decode(Double.self) as! T }
        if type == Float.self { return try decode(Float.self) as! T }
        if type == Int.self { return try decode(Int.self) as! T }
        if type == Int8.self { return try decode(Int8.self) as! T }
        if type == Int16.self { return try decode(Int16.self) as! T }
        if type == Int32.self { return try decode(Int32.self) as! T }
        if type == Int64.self { return try decode(Int64.self) as! T }
        if type == UInt.self { return try decode(UInt.self) as! T }
        if type == UInt8.self { return try decode(UInt8.self) as! T }
        if type == UInt16.self { return try decode(UInt16.self) as! T }
        if type == UInt32.self { return try decode(UInt32.self) as! T }
        if type == UInt64.self { return try decode(UInt64.self) as! T }
        return try T(from: decoder)
    }

    private func typeMismatch(_ type: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "期望 \(type)，实际为: \(node.rawValue)"))
    }
}

// MARK: - 内部 CodingKey

private struct _TOMLCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init(intValue: Int) { self.stringValue = "Index \(intValue)"; self.intValue = intValue }
    init(index: Int) { self.stringValue = "Index \(index)"; self.intValue = index }
}
