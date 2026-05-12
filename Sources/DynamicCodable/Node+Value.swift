//
//  Node+Value.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/4.
//

import Foundation

extension Node {
    
    public enum Value: Sendable {
        case null
        case bool(Bool)
        case number(String)
        case string(String)
        case array([Node])
        case object(OrderedDictionary<String, Node>)
        case error(Node.Error, ignore: [String])
    }
}

extension Node.Value {
    
    public var decimal: Decimal {
        if case let .number(number) = self,
           let value = try? Decimal(number, format: .number, lenient: true) {
            return value
        }
        return 0
    }
    
    public var float: Float {
        Float(double)
    }
    
    public var double: Double {
        if case let .number(number) = self,
           let value = try? Double(number, format: .number, lenient: true) {
            return value
        }
        return 0.0
    }
    
    public var int128: Int128 {
        let doubleValue = double
        if  doubleValue >= Double(Int128.max) { return Int128.max }
        if  doubleValue <= Double(Int128.min) { return Int128.min }
        if case let .number(number) = self,
           let value = Int128(number) {
            return value
        }
        return 0
    }
    
    public var uint128: UInt128 {
        let doubleValue = double
        if  doubleValue >= Double(UInt128.max) { return UInt128.max }
        if case let .number(number) = self,
           let value = UInt128(number) {
            return value
        }
        return 0
    }
    
    public var int64: Int64 {
        let doubleValue = double
        if  doubleValue >= Double(Int64.max) { return Int64.max }
        if  doubleValue <= Double(Int64.min) { return Int64.min }
        if case let .number(number) = self,
           let value = try? Int64(number, format: .number, lenient: true) {
            return value
        }
        return 0
    }
    
    public var uint64: UInt64 {
        let doubleValue = double
        if  doubleValue >= Double(UInt64.max) { return UInt64.max }
        if case let .number(number) = self,
           let value = try? UInt64(number, format: .number, lenient: true) {
            return value
        }
        return 0
    }
    
    public var char: CChar {
        CChar(truncatingIfNeeded: int64)
    }
    
    public var int8: Int8 {
        Int8(truncatingIfNeeded: int64)
    }

    public var uint8: UInt8 {
        UInt8(truncatingIfNeeded: uint64)
    }

    public var int16: Int16 {
        Int16(truncatingIfNeeded: int64)
    }

    public var uint16: UInt16 {
        UInt16(truncatingIfNeeded: uint64)
    }

    public var int32: Int32 {
        Int32(truncatingIfNeeded: int64)
    }

    public var uint32: UInt32 {
        UInt32(truncatingIfNeeded: uint64)
    }

    public var bool: Bool {
        double != 0
    }

    public var int: Int {
        Int(truncatingIfNeeded: int64)
    }

    public var uint: UInt {
        UInt(truncatingIfNeeded: uint64)
    }
    
}


extension Node.Value: Equatable {
    
    public static func == (lhs: Node.Value, rhs: Node.Value) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true
        case let (.bool(lhsBool), .bool(rhsBool)):
            return lhsBool == rhsBool
        case let (.number(lhsNumber), .number(rhsNumber)):
            return Double(lhsNumber) == Double(rhsNumber)
        case let (.string(lhsString), .string(rhsString)):
            return lhsString == rhsString
        case let (.array(lhsArray), .array(rhsArray)):
            return lhsArray == rhsArray
        case let (.object(lhsObject), .object(rhsObject)):
            return lhsObject == rhsObject
        case let (.error(lhsErr, lhsPath), .error(rhsErr, rhsPath)):
            return lhsPath == rhsPath && lhsErr == rhsErr
        default:
            return false
        }
    }
}

extension Node.Value: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null: return "null"
        case .bool(let v): return "\(v)"
        case .number(let v): return "\(v)"
        case .string(let v): return "\"\(v)\""
        case .array(let members):
            return "[\(members.map(\.description).joined(separator: ", "))]"
        case .object(let members):
            let pairs = members.map { "\($0.key): \($0.value.description)" }
            return "{\(pairs.joined(separator: ", "))}"
        case .error(let error, ignore: let ignore):
            return "At path:\(ignore.joined(separator: "/")) Error: \(error.localizedDescription)"
        }
    }
}

extension Node.Value: CustomDebugStringConvertible {
    public var debugDescription: String {
        description
    }
}

