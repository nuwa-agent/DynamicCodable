//
//  TOMLEncoder.swift
//  Nuwa
//

import Foundation
import DynamicCodable

public struct TOMLEncoder {

    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> String {
        if let node = value as? Node {
            return TOMLSerializer().serialize(node)
        }
        let encoder = _TOMLEncoder(userInfo: userInfo, codingPath: [])
        try value.encode(to: encoder)
        guard let node = encoder.node?.node else {
            throw TOMLError.encodingError("编码后未生成任何值")
        }
        return TOMLSerializer().serialize(node)
    }
}

// MARK: - Node 引用包装器

private final class NodeRef {
    var node: Node
    init(_ node: Node) { self.node = node }
}

// MARK: - 内部 Encoder

private class _TOMLEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var node: NodeRef?

    init(userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey]) {
        self.userInfo = userInfo
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        if node == nil {
            node = NodeRef(Node(.object(OrderedDictionary())))
        } else if case .object = node!.node.rawValue {
            // 已是对象，复用
        } else {
            let old = node!.node
            var dict = OrderedDictionary<String, Node>()
            dict["_value"] = old
            node = NodeRef(Node(.object(dict)))
        }
        let container = _TOMLKeyedEncodingContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if node == nil {
            node = NodeRef(Node(.array([])))
        } else if case .array = node!.node.rawValue {
            // 复用
        } else {
            node = NodeRef(Node(.array([node!.node])))
        }
        return _TOMLUnkeyedEncodingContainer(encoder: self, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return _TOMLSingleValueEncodingContainer(encoder: self, codingPath: codingPath)
    }
}

// MARK: - 键容器

private struct _TOMLKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _TOMLEncoder
    var codingPath: [CodingKey]
    var nestedRefs: [String: NodeRef] = [:]

    private var dict: OrderedDictionary<String, Node> {
        get {
            guard let ref = encoder.node, case .object(var d) = ref.node.rawValue else { return OrderedDictionary() }
            var needsSync = false
            for (key, childRef) in nestedRefs {
                if d[key] != childRef.node { d[key] = childRef.node; needsSync = true }
            }
            if needsSync { encoder.node?.node = Node(.object(d)) }
            return d
        }
        set {
            var newDict = newValue
            for (key, childRef) in nestedRefs { newDict[key] = childRef.node }
            encoder.node?.node = Node(.object(newDict))
        }
    }

    mutating func encodeNil(forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.null); dict = d }
    mutating func encode(_ value: Bool, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.bool(value)); dict = d }
    mutating func encode(_ value: String, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.string(value)); dict = d }
    mutating func encode(_ value: Double, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: Float, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: Int, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: Int8, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: Int16, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: Int32, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: Int64, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: UInt, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { var d = dict; d[key.stringValue] = Node(.number(value.description)); dict = d }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        if let bool = value as? Bool { try encode(bool, forKey: key); return }
        if let string = value as? String { try encode(string, forKey: key); return }
        if let double = value as? Double { try encode(double, forKey: key); return }
        if let float = value as? Float { try encode(float, forKey: key); return }
        if let int = value as? Int { try encode(int, forKey: key); return }
        if let int8 = value as? Int8 { try encode(int8, forKey: key); return }
        if let int16 = value as? Int16 { try encode(int16, forKey: key); return }
        if let int32 = value as? Int32 { try encode(int32, forKey: key); return }
        if let int64 = value as? Int64 { try encode(int64, forKey: key); return }
        if let uint = value as? UInt { try encode(uint, forKey: key); return }
        if let uint8 = value as? UInt8 { try encode(uint8, forKey: key); return }
        if let uint16 = value as? UInt16 { try encode(uint16, forKey: key); return }
        if let uint32 = value as? UInt32 { try encode(uint32, forKey: key); return }
        if let uint64 = value as? UInt64 { try encode(uint64, forKey: key); return }
        let child = _TOMLEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [_TOMLCodingKey(stringValue: key.stringValue)])
        try value.encode(to: child)
        if let childNode = child.node {
            var d = dict
            d[key.stringValue] = childNode.node
            dict = d
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let child = _TOMLEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [_TOMLCodingKey(stringValue: key.stringValue)])
        let objRef = NodeRef(Node(.object(OrderedDictionary())))
        child.node = objRef
        nestedRefs[key.stringValue] = objRef
        var d = dict; d[key.stringValue] = objRef.node; dict = d
        var container = _TOMLKeyedEncodingContainer<NestedKey>(encoder: child, codingPath: child.codingPath)
        container.nestedRefs = nestedRefs
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let child = _TOMLEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [_TOMLCodingKey(stringValue: key.stringValue)])
        let arrRef = NodeRef(Node(.array([])))
        child.node = arrRef
        nestedRefs[key.stringValue] = arrRef
        var d = dict; d[key.stringValue] = arrRef.node; dict = d
        return _TOMLUnkeyedEncodingContainer(encoder: child, codingPath: child.codingPath)
    }

    mutating func superEncoder() -> Encoder { encoder }
    mutating func superEncoder(forKey key: Key) -> Encoder {
        _TOMLEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [_TOMLCodingKey(stringValue: key.stringValue)])
    }
}

// MARK: - 无键容器

private struct _TOMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _TOMLEncoder
    var codingPath: [CodingKey]
    var count: Int {
        guard let ref = encoder.node, case .array(let arr) = ref.node.rawValue else { return 0 }
        return arr.count
    }

    private var items: [Node] {
        get {
            guard let ref = encoder.node, case .array(let arr) = ref.node.rawValue else { return [] }
            return arr
        }
        set { encoder.node?.node = Node(.array(newValue)) }
    }

    mutating func encodeNil() throws { var arr = items; arr.append(Node(.null)); items = arr }
    mutating func encode(_ value: Bool) throws { var arr = items; arr.append(Node(.bool(value))); items = arr }
    mutating func encode(_ value: String) throws { var arr = items; arr.append(Node(.string(value))); items = arr }
    mutating func encode(_ value: Double) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: Float) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: Int) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: Int8) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: Int16) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: Int32) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: Int64) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: UInt) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: UInt8) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: UInt16) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: UInt32) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }
    mutating func encode(_ value: UInt64) throws { var arr = items; arr.append(Node(.number(value.description))); items = arr }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if let bool = value as? Bool { try encode(bool); return }
        if let string = value as? String { try encode(string); return }
        if let double = value as? Double { try encode(double); return }
        if let float = value as? Float { try encode(float); return }
        if let int = value as? Int { try encode(int); return }
        if let int8 = value as? Int8 { try encode(int8); return }
        if let int16 = value as? Int16 { try encode(int16); return }
        if let int32 = value as? Int32 { try encode(int32); return }
        if let int64 = value as? Int64 { try encode(int64); return }
        if let uint = value as? UInt { try encode(uint); return }
        if let uint8 = value as? UInt8 { try encode(uint8); return }
        if let uint16 = value as? UInt16 { try encode(uint16); return }
        if let uint32 = value as? UInt32 { try encode(uint32); return }
        if let uint64 = value as? UInt64 { try encode(uint64); return }
        let idx = items.count
        let child = _TOMLEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [_TOMLCodingKey(index: idx)])
        try value.encode(to: child)
        if let childNode = child.node { var arr = items; arr.append(childNode.node); items = arr }
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let idx = items.count
        let child = _TOMLEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [_TOMLCodingKey(index: idx)])
        let objRef = NodeRef(Node(.object(OrderedDictionary())))
        child.node = objRef
        var arr = items; arr.append(objRef.node); items = arr
        let container = _TOMLKeyedEncodingContainer<NestedKey>(encoder: child, codingPath: child.codingPath)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let idx = items.count
        let child = _TOMLEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [_TOMLCodingKey(index: idx)])
        let arrRef = NodeRef(Node(.array([])))
        child.node = arrRef
        var arr = items; arr.append(arrRef.node); items = arr
        return _TOMLUnkeyedEncodingContainer(encoder: child, codingPath: child.codingPath)
    }

    mutating func superEncoder() -> Encoder { encoder }
}

// MARK: - 单值容器

private struct _TOMLSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: _TOMLEncoder
    var codingPath: [CodingKey]

    mutating func encodeNil() throws { encoder.node = NodeRef(Node(.null)) }
    mutating func encode(_ value: Bool) throws { encoder.node = NodeRef(Node(.bool(value))) }
    mutating func encode(_ value: String) throws { encoder.node = NodeRef(Node(.string(value))) }
    mutating func encode(_ value: Double) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: Float) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: Int) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: Int8) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: Int16) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: Int32) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: Int64) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: UInt) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: UInt8) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: UInt16) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: UInt32) throws { encoder.node = NodeRef(Node(.number(value.description))) }
    mutating func encode(_ value: UInt64) throws { encoder.node = NodeRef(Node(.number(value.description))) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if let bool = value as? Bool { try encode(bool); return }
        if let string = value as? String { try encode(string); return }
        if let double = value as? Double { try encode(double); return }
        if let float = value as? Float { try encode(float); return }
        if let int = value as? Int { try encode(int); return }
        if let int8 = value as? Int8 { try encode(int8); return }
        if let int16 = value as? Int16 { try encode(int16); return }
        if let int32 = value as? Int32 { try encode(int32); return }
        if let int64 = value as? Int64 { try encode(int64); return }
        if let uint = value as? UInt { try encode(uint); return }
        if let uint8 = value as? UInt8 { try encode(uint8); return }
        if let uint16 = value as? UInt16 { try encode(uint16); return }
        if let uint32 = value as? UInt32 { try encode(uint32); return }
        if let uint64 = value as? UInt64 { try encode(uint64); return }
        try value.encode(to: encoder)
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
