//
//  YAMLEncoder.swift
//  Nuwa
//
//  YAML 编码器：将任意 Encodable 类型编码为 YAML 字符串
//
//  工作流程：
//    1. 使用内部 _YAMLEncoder 将目标类型编码为 Node 树
//    2. 使用 YAMLSerializer 将 Node 树序列化为 YAML 文本
//
//  参考 Foundation 中 JSONEncoder 的实现模式
//

import Foundation
import DynamicCodable

/// YAML 编码器
/// 将符合 Encodable 协议的类型编码为 YAML 格式的字符串
public struct YAMLEncoder {

    /// 用户自定义信息字典
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    // MARK: - 公开编码方法

    /// 将值编码为 YAML 字符串
    /// - Parameter value: 要编码的 Encodable 值
    /// - Returns: YAML 格式的字符串
    public func encode<T: Encodable>(_ value: T) throws -> String {
        // 如果值本身是 Node，直接序列化
        if let node = value as? Node {
            return YAMLSerializer().serialize(node)
        }
        // 编码为 Node → 序列化为 YAML
        let encoder = _YAMLEncoder(userInfo: userInfo, codingPath: [])
        try value.encode(to: encoder)
        guard let node = encoder.node?.node else {
            throw YAMLError.encodingError("编码后未生成任何值")
        }
        return YAMLSerializer().serialize(node)
    }
}

// MARK: - Node 引用包装器

/// Node 的引用包装器，用于在 Encoder 容器间共享可变状态
/// 解决值类型 Node 在嵌套编码器中无法双向同步的问题
private final class NodeRef {
    var node: Node
    init(_ node: Node) { self.node = node }
}

// MARK: - 内部 Encoder 实现

/// 内部 YAML Encoder，使用 NodeRef 管理可变 Node 引用
private class _YAMLEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    /// 编码结果的可变引用
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
            // 将现有值包装为对象
            let old = node!.node
            var dict = OrderedDictionary<String, Node>()
            dict["_value"] = old
            node = NodeRef(Node(.object(dict)))
        }
        let container = _YAMLKeyedEncodingContainer<Key>(
            encoder: self,
            codingPath: codingPath
        )
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if node == nil {
            node = NodeRef(Node(.array([])))
        } else if case .array = node!.node.rawValue {
            // 已是数组，复用
        } else {
            // 将现有值包装为数组
            node = NodeRef(Node(.array([node!.node])))
        }
        return _YAMLUnkeyedEncodingContainer(
            encoder: self,
            codingPath: codingPath
        )
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return _YAMLSingleValueEncodingContainer(
            encoder: self,
            codingPath: codingPath
        )
    }
}

// MARK: - 键容器（KeyedEncodingContainer）

private struct _YAMLKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _YAMLEncoder
    var codingPath: [CodingKey]
    /// 跟踪嵌套容器的 NodeRef，确保子编码器的修改能同步回父字典
    var nestedRefs: [String: NodeRef] = [:]

    /// 获取或设置对象字典，自动同步嵌套容器的修改
    private var dict: OrderedDictionary<String, Node> {
        get {
            guard let ref = encoder.node,
                  case .object(var d) = ref.node.rawValue else {
                return OrderedDictionary()
            }
            var needsSync = false
            for (key, childRef) in nestedRefs {
                if d[key] != childRef.node {
                    d[key] = childRef.node
                    needsSync = true
                }
            }
            if needsSync {
                encoder.node?.node = Node(.object(d))
            }
            return d
        }
        set {
            var newDict = newValue
            for (key, childRef) in nestedRefs {
                newDict[key] = childRef.node
            }
            encoder.node?.node = Node(.object(newDict))
        }
    }

    mutating func encodeNil(forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.null)
        dict = d
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.bool(value))
        dict = d
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.string(value))
        dict = d
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        var d = dict
        d[key.stringValue] = Node(.number(value.description))
        dict = d
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        // 标量类型直接编码
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

        // 复合类型：嵌套编码
        let child = _YAMLEncoder(
            userInfo: encoder.userInfo,
            codingPath: codingPath + [_YAMLCodingKey(stringValue: key.stringValue)]
        )
        try value.encode(to: child)
        if let childNode = child.node {
            var d = dict
            d[key.stringValue] = childNode.node
            dict = d
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let child = _YAMLEncoder(
            userInfo: encoder.userInfo,
            codingPath: codingPath + [_YAMLCodingKey(stringValue: key.stringValue)]
        )
        let objRef = NodeRef(Node(.object(OrderedDictionary())))
        child.node = objRef
        // 记录 NodeRef 以便后续同步子编码器的修改
        nestedRefs[key.stringValue] = objRef
        var d = dict
        d[key.stringValue] = objRef.node
        dict = d
        var container = _YAMLKeyedEncodingContainer<NestedKey>(
            encoder: child,
            codingPath: child.codingPath
        )
        container.nestedRefs = nestedRefs
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let child = _YAMLEncoder(
            userInfo: encoder.userInfo,
            codingPath: codingPath + [_YAMLCodingKey(stringValue: key.stringValue)]
        )
        let arrRef = NodeRef(Node(.array([])))
        child.node = arrRef
        nestedRefs[key.stringValue] = arrRef
        var d = dict
        d[key.stringValue] = arrRef.node
        dict = d
        return _YAMLUnkeyedEncodingContainer(
            encoder: child,
            codingPath: child.codingPath
        )
    }

    mutating func superEncoder() -> Encoder {
        return encoder
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        return _YAMLEncoder(
            userInfo: encoder.userInfo,
            codingPath: codingPath + [_YAMLCodingKey(stringValue: key.stringValue)]
        )
    }
}

// MARK: - 无键容器（UnkeyedEncodingContainer）

private struct _YAMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _YAMLEncoder
    var codingPath: [CodingKey]
    var count: Int {
        guard let ref = encoder.node,
              case .array(let arr) = ref.node.rawValue else { return 0 }
        return arr.count
    }

    /// 获取或设置数组
    private var items: [Node] {
        get {
            guard let ref = encoder.node,
                  case .array(let arr) = ref.node.rawValue else { return [] }
            return arr
        }
        set {
            encoder.node?.node = Node(.array(newValue))
        }
    }

    mutating func encodeNil() throws {
        var arr = items; arr.append(Node(.null)); items = arr
    }

    mutating func encode(_ value: Bool) throws {
        var arr = items; arr.append(Node(.bool(value))); items = arr
    }

    mutating func encode(_ value: String) throws {
        var arr = items; arr.append(Node(.string(value))); items = arr
    }

    mutating func encode(_ value: Double) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: Float) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: Int) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: Int8) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: Int16) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: Int32) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: Int64) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: UInt) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: UInt8) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: UInt16) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: UInt32) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode(_ value: UInt64) throws {
        var arr = items; arr.append(Node(.number(value.description))); items = arr
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        // 标量类型直接编码
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

        // 复合类型：嵌套编码
        let idx = items.count
        let child = _YAMLEncoder(
            userInfo: encoder.userInfo,
            codingPath: codingPath + [_YAMLCodingKey(index: idx)]
        )
        try value.encode(to: child)
        if let childNode = child.node {
            var arr = items; arr.append(childNode.node); items = arr
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let idx = items.count
        let child = _YAMLEncoder(
            userInfo: encoder.userInfo,
            codingPath: codingPath + [_YAMLCodingKey(index: idx)]
        )
        let objRef = NodeRef(Node(.object(OrderedDictionary())))
        child.node = objRef
        var arr = items; arr.append(objRef.node); items = arr
        let container = _YAMLKeyedEncodingContainer<NestedKey>(
            encoder: child,
            codingPath: child.codingPath
        )
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let idx = items.count
        let child = _YAMLEncoder(
            userInfo: encoder.userInfo,
            codingPath: codingPath + [_YAMLCodingKey(index: idx)]
        )
        let arrRef = NodeRef(Node(.array([])))
        child.node = arrRef
        var arr = items; arr.append(arrRef.node); items = arr
        return _YAMLUnkeyedEncodingContainer(
            encoder: child,
            codingPath: child.codingPath
        )
    }

    mutating func superEncoder() -> Encoder {
        return encoder
    }
}

// MARK: - 单值容器（SingleValueEncodingContainer）

private struct _YAMLSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: _YAMLEncoder
    var codingPath: [CodingKey]

    mutating func encodeNil() throws {
        encoder.node = NodeRef(Node(.null))
    }

    mutating func encode(_ value: Bool) throws {
        encoder.node = NodeRef(Node(.bool(value)))
    }

    mutating func encode(_ value: String) throws {
        encoder.node = NodeRef(Node(.string(value)))
    }

    mutating func encode(_ value: Double) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: Float) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: Int) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: Int8) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: Int16) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: Int32) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: Int64) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: UInt) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: UInt8) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: UInt16) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: UInt32) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode(_ value: UInt64) throws {
        encoder.node = NodeRef(Node(.number(value.description)))
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        // 标量类型直接编码
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
        // 复合类型委托给子 encoder
        try value.encode(to: encoder)
    }
}

/// 内部 CodingKey 实现
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
