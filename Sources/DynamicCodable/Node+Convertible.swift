//
//  Node+Convertible.swift
//  DynamicCodable
//
//  Created by yNasMac on 2026/5/31.
//
// MARK: - Node.Convertible

import Foundation
import OrderedCollections

extension Node {
    public protocol Convertible {
        var asNode: Node { get }
    }
}

extension Node.Convertible where Self: RawRepresentable, RawValue: Node.Convertible {
    public var asNode: Node {
        rawValue.asNode
    }
}

extension Node.Convertible where Self: Sequence, Element: Node.Convertible {
    public var asNode: Node {
        .array(map(\.asNode))
    }
}

// MARK: - 标准类型实现
extension Node.Value: Node.Convertible {
    public var asNode: Node {
        Node(self)
    }
}

extension OrderedDictionary: Node.Convertible where Key == String {
    public var asNode: Node {
        .object(mapValues({ Node.from($0) }))
    }
}

extension Dictionary: Node.Convertible where Key == String {
    public var asNode: Node {
        .object(Node.Object(
            uniqueKeysWithValues: map {
                ($0.key, Node.from($0.value))
            }
        ))
    }
}

extension Array: Node.Convertible {
    public var asNode: Node {
        .array(map({ Node.from($0) }))
    }
}

extension Bool:   Node.Convertible {
    public var asNode: Node { .bool(self) }
}
extension String: Node.Convertible {
    public var asNode: Node { .string(self) }
}
extension Float:  Node.Convertible {
    public var asNode: Node { .float(self) }
}
extension Double: Node.Convertible {
    public var asNode: Node { .double(self) }
}
extension Decimal:Node.Convertible {
    public var asNode: Node { .decimal(self) }
}
extension NSNull: Node.Convertible  {
    public var asNode: Node { .null }
}
extension FixedWidthInteger where Self: Node.Convertible  {
    public var asNode: Node { .number(description) }
}
extension Int:    Node.Convertible {}
extension Int8:   Node.Convertible {}
extension Int16:  Node.Convertible {}
extension Int32:  Node.Convertible {}
extension Int64:  Node.Convertible {}
extension UInt:   Node.Convertible {}
extension UInt8:  Node.Convertible {}
extension UInt16: Node.Convertible {}
extension UInt32: Node.Convertible {}
extension UInt64: Node.Convertible {}
@available(macOS 15.0, *)
extension Int128:  Node.Convertible {}
@available(macOS 15.0, *)
extension UInt128: Node.Convertible {}
