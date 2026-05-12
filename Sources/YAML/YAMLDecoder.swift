//
//  YAMLDecoder.swift
//  Nuwa
//
//  YAML 解码器：将 YAML 字符串解码为任意 Decodable 类型
//
//  工作流程：
//    1. 使用 YAMLParser 将 YAML 文本解析为 Node 树
//    2. 使用内部 _YAMLDecoder 将 Node 树桥接为 Decoder 协议
//    3. 目标类型的 init(from:) 通过容器协议读取数据
//
//  参考 Foundation 中 JSONDecoder 的实现模式
//

import Foundation
import DynamicCodable

/// YAML 解码器
/// 将 YAML 格式的字符串解码为符合 Decodable 协议的类型
public struct YAMLDecoder {

    /// 用户自定义信息字典，传递给解码过程中的 CodingUserInfoKey
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    // MARK: - 公开解码方法

    /// 从 YAML 字符串解码为目标类型
    /// - Parameters:
    ///   - type: 目标 Decodable 类型
    ///   - yaml: YAML 格式字符串
    /// - Returns: 解码后的目标类型实例
    public func decode<T: Decodable>(_ type: T.Type, from yaml: String) throws -> T {
        // 如果目标是 Node 类型，直接返回解析结果
        if type == Node.self {
            let node = try YAMLParser().parse(yaml)
            return node as! T
        }
        // 解析 YAML → Node → 内部 Decoder → 目标类型
        let node = try YAMLParser().parse(yaml)
        let decoder = _YAMLDecoder(node: node, userInfo: userInfo, codingPath: [])
        return try T(from: decoder)
    }
}

// MARK: - 内部 Decoder 实现

/// 内部 YAML Decoder，将 Node 树桥接为 Decoder 协议
/// 参考 JSONDecoder 的内部 _JSONDecoder 实现
private class _YAMLDecoder: Decoder {
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
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "期望对象类型，实际为: \(node.rawValue)"
                )
            )
        }
        let container = _YAMLKeyedDecodingContainer<Key>(
            dict: dict,
            decoder: self,
            codingPath: codingPath
        )
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let items) = node.rawValue else {
            throw DecodingError.typeMismatch(
                [Any].self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "期望数组类型，实际为: \(node.rawValue)"
                )
            )
        }
        return _YAMLUnkeyedDecodingContainer(
            items: items,
            decoder: self,
            codingPath: codingPath
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return _YAMLSingleValueDecodingContainer(
            node: node,
            decoder: self,
            codingPath: codingPath
        )
    }
}

// MARK: - 键容器（KeyedDecodingContainer）

private struct _YAMLKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let dict: OrderedDictionary<String, Node>
    let decoder: _YAMLDecoder
    var codingPath: [CodingKey]

    var allKeys: [Key] {
        return dict.keys.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        return dict.keys.contains(key.stringValue)
    }

    /// 获取指定键对应的 Node，不存在则抛出 keyNotFound 错误
    private func node(forKey key: Key) throws -> Node {
        guard let node = dict[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "未找到键: \(key.stringValue)"
                )
            )
        }
        return node
    }

    /// 为子节点创建新的 decoder
    private func decoderForNode(_ node: Node, key: CodingKey) -> _YAMLDecoder {
        return _YAMLDecoder(
            node: node,
            userInfo: decoder.userInfo,
            codingPath: codingPath + [key]
        )
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
        return Float(try decode(Double.self, forKey: key))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let node = try self.node(forKey: key)
        return try decodeInt(node: node, forKey: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return Int8(truncatingIfNeeded: try decode(Int.self, forKey: key))
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return Int16(truncatingIfNeeded: try decode(Int.self, forKey: key))
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return Int32(truncatingIfNeeded: try decode(Int.self, forKey: key))
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        let node = try self.node(forKey: key)
        return try decodeInt64(node: node, forKey: key)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        let node = try self.node(forKey: key)
        return try decodeUInt(node: node, forKey: key)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return UInt8(truncatingIfNeeded: try decode(UInt.self, forKey: key))
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return UInt16(truncatingIfNeeded: try decode(UInt.self, forKey: key))
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return UInt32(truncatingIfNeeded: try decode(UInt.self, forKey: key))
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        let node = try self.node(forKey: key)
        return try decodeUInt64(node: node, forKey: key)
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let node = try self.node(forKey: key)
        // 对于标量类型，直接从 Node 值中提取
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
        // 复合类型使用嵌套 decoder
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

    func superDecoder() throws -> Decoder {
        return decoder
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        let node = try self.node(forKey: key)
        return decoderForNode(node, key: key)
    }

    // MARK: 数字解码辅助

    private func typeMismatch(_ type: Any.Type, forKey key: Key, node: Node) -> DecodingError {
        return DecodingError.typeMismatch(
            type,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "期望 \(type)，实际为: \(node.rawValue)"
            )
        )
    }

    private func decodeDouble(node: Node, forKey key: Key) throws -> Double {
        switch node.rawValue {
        case .number(let v):
            if let d = Double(v) { return d }
        case .string(let v):
            if let d = Double(v) { return d }
        case .bool(let v):
            return v ? 1.0 : 0.0
        default: break
        }
        throw typeMismatch(Double.self, forKey: key, node: node)
    }

    private func decodeInt(node: Node, forKey key: Key) throws -> Int {
        switch node.rawValue {
        case .number(let v):
            if let i = Int(v) { return i }
        case .string(let v):
            if let i = Int(v) { return i }
        case .bool(let v):
            return v ? 1 : 0
        default: break
        }
        throw typeMismatch(Int.self, forKey: key, node: node)
    }

    private func decodeInt64(node: Node, forKey key: Key) throws -> Int64 {
        switch node.rawValue {
        case .number(let v):
            if let i = Int64(v) { return i }
        case .string(let v):
            if let i = Int64(v) { return i }
        case .bool(let v):
            return v ? 1 : 0
        default: break
        }
        throw typeMismatch(Int64.self, forKey: key, node: node)
    }

    private func decodeUInt(node: Node, forKey key: Key) throws -> UInt {
        switch node.rawValue {
        case .number(let v):
            if let i = UInt(v) { return i }
        case .string(let v):
            if let i = UInt(v) { return i }
        case .bool(let v):
            return v ? 1 : 0
        default: break
        }
        throw typeMismatch(UInt.self, forKey: key, node: node)
    }

    private func decodeUInt64(node: Node, forKey key: Key) throws -> UInt64 {
        switch node.rawValue {
        case .number(let v):
            if let i = UInt64(v) { return i }
        case .string(let v):
            if let i = UInt64(v) { return i }
        case .bool(let v):
            return v ? 1 : 0
        default: break
        }
        throw typeMismatch(UInt64.self, forKey: key, node: node)
    }
}

// MARK: - 无键容器（UnkeyedDecodingContainer）

private struct _YAMLUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let items: [Node]
    let decoder: _YAMLDecoder
    var codingPath: [CodingKey]

    var currentIndex: Int = 0

    var count: Int? { return items.count }
    var isAtEnd: Bool { return currentIndex >= items.count }

    private var currentItem: Node {
        return items[currentIndex]
    }

    private mutating func advance() {
        currentIndex += 1
    }

    private func childDecoder(for node: Node) -> _YAMLDecoder {
        let key = _YAMLCodingKey(index: currentIndex)
        return _YAMLDecoder(
            node: node,
            userInfo: decoder.userInfo,
            codingPath: codingPath + [key]
        )
    }

    private func typeMismatchError(_ type: Any.Type) -> DecodingError {
        let key = _YAMLCodingKey(index: currentIndex)
        return DecodingError.typeMismatch(
            type,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "期望 \(type)，实际为: \(currentItem.rawValue)"
            )
        )
    }

    mutating func decodeNil() throws -> Bool {
        if case .null = currentItem.rawValue {
            advance()
            return true
        }
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

    mutating func decode(_ type: Float.Type) throws -> Float {
        return Float(try decode(Double.self))
    }

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

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        return Int8(truncatingIfNeeded: try decode(Int.self))
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        return Int16(truncatingIfNeeded: try decode(Int.self))
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        return Int32(truncatingIfNeeded: try decode(Int.self))
    }

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

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        return UInt8(truncatingIfNeeded: try decode(UInt.self))
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        return UInt16(truncatingIfNeeded: try decode(UInt.self))
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        return UInt32(truncatingIfNeeded: try decode(UInt.self))
    }

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
        // 标量类型直接提取
        if type == Bool.self { return try decode(Bool.self) as! T }
        if type == String.self { return try decode(String.self) as! T }
        if type == Double.self { return try decode(Double.self) as! T }
        if type == Float.self { return try decode(Float.self) as! T }
        if type == Int.self { return try decode(Int.self) as! T }
        if type == Int64.self { return try decode(Int64.self) as! T }
        if type == UInt.self { return try decode(UInt.self) as! T }
        if type == UInt64.self { return try decode(UInt64.self) as! T }
        // 复合类型
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

// MARK: - 单值容器（SingleValueDecodingContainer）

private struct _YAMLSingleValueDecodingContainer: SingleValueDecodingContainer {
    let node: Node
    let decoder: _YAMLDecoder
    var codingPath: [CodingKey]

    func decodeNil() -> Bool {
        if case .null = node.rawValue { return true }
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        switch node.rawValue {
        case .bool(let v): return v
        case .string(let v):
            switch v.lowercased() {
            case "true", "yes", "on": return true
            case "false", "no", "off": return false
            default: break
            }
        case .number(let v):
            return (Double(v) ?? 0) != 0
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

    func decode(_ type: Float.Type) throws -> Float {
        return Float(try decode(Double.self))
    }

    func decode(_ type: Int.Type) throws -> Int {
        switch node.rawValue {
        case .number(let v): if let i = Int(v) { return i }
        case .string(let v): if let i = Int(v) { return i }
        case .bool(let v): return v ? 1 : 0
        default: break
        }
        throw typeMismatch(type)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        return Int8(truncatingIfNeeded: try decode(Int.self))
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        return Int16(truncatingIfNeeded: try decode(Int.self))
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        return Int32(truncatingIfNeeded: try decode(Int.self))
    }

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

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        return UInt8(truncatingIfNeeded: try decode(UInt.self))
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        return UInt16(truncatingIfNeeded: try decode(UInt.self))
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        return UInt32(truncatingIfNeeded: try decode(UInt.self))
    }

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
        return DecodingError.typeMismatch(
            type,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "期望 \(type)，实际为: \(node.rawValue)"
            )
        )
    }
}

// MARK: - 内部 CodingKey

/// 用于数组索引的 CodingKey
private struct _YAMLCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = "Index \(intValue)"
        self.intValue = intValue
    }

    init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
}
