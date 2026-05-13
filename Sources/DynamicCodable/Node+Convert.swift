//
//  Node+Convert.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/4.
//
import Foundation

extension Node {
        
    public static let null: Node = Node(.null)
    public static let `true`: Node = Node(.bool(true))
    public static let `false`: Node = Node(.bool(false))
    
    public static func bool(_ value: Bool?) -> Node {
        if let value = value {
            return Node(.bool(value))
        }
        return .null
    }
    public static func number(_ value: String?) -> Node {
        if let value = value {
            return Node(.number(value))
        }
        return .null
    }
    public static func string(_ value: String?) -> Node {
        if let value = value {
            return Node(.string(value))
        }
        return .null
    }
    public static func string<S>(_ value:S) -> Node where S : RawRepresentable, S.RawValue == String {
        Node(.string(value.rawValue))
    }
    public static func object(_ value: OrderedDictionary<String, Node>?) -> Node {
        if let value = value {
            return Node(.object(value))
        }
        return .null
    }
    public static func array(_ value: [Node]?) -> Node {
        if let value = value {
            return Node(.array(value))
        }
        return .null
    }
    public static func array<S>(_ value:S) -> Node where S : Sequence, S.Element == Value {
        return Node.array(value.map(Node.init))
    }
    public static func error(_ value: Node.Error, ignore path: [String]) -> Node {
        return Node(.error(value, ignore: path))
    }
    public static func error<S>(_ value:S, ignore path: [String]) -> Node where S : Swift.Error {
        return Node(.error(.otherError(value), ignore: path))
    }
}

// MARK: - 类型判断
extension Node {
    
    public var isBool:Bool {
        if case .bool = rawValue { return true }
        if case .string(let value) = rawValue {
            return value == "true" || value == "false"
        }
        return false
    }
    public var isArray:Bool {
        if case .array = rawValue { return true }
        return false
    }
    public var isObject:Bool {
        if case .object = rawValue { return true }
        return false
    }
    public var isNumber:Bool {
        if case .number = rawValue { return true }
        return false
    }
    public var isString:Bool {
        if case .string = rawValue { return true }
        return false
    }
    public var isNullOrError:Bool {
        if case .null = rawValue { return true }
        if case .error = rawValue { return true }
        return false
    }
    public var isNull:Bool {
        if case .null = rawValue { return true }
        return false
    }
    public var isError:Bool {
        if case .error = rawValue { return true }
        return false
    }
    
}

// MARK: - 从其他值转化
extension Node {
    public static func from(_ value: Any?) -> Node {
        if #available(macOS 15.0, *) {
            if let v = value as? Int128 { return Node.int128(v) }
            if let v = value as? UInt128 { return Node.uint128(v) }
        }
        switch value {
        case let v as Node:         return v
        case let v as Value:        return Node(v)
        case let v as [Node]:       return Node.array(v)
        case let v as Object:       return Node.object(v)
        case let v as Bool:         return Node.bool(v)
        case let v as String:       return Node.string(v)
        case let v as NSNumber:     return Node.number(v.stringValue)
        case let v as Decimal:      return Node.decimal(v)
        case let v as Float:        return Node.float(v)
        case let v as Double:       return Node.double(v)
        case let v as CChar:        return Node.char(v)
        case let v as Int64:        return Node.int64(v)
        case let v as Int32:        return Node.int32(v)
        case let v as Int16:        return Node.int16(v)
        case let v as Int8:         return Node.int8(v)
        case let v as Int:          return Node.int(v)
        case let v as UInt64:       return Node.uint64(v)
        case let v as UInt32:       return Node.uint32(v)
        case let v as UInt16:       return Node.uint16(v)
        case let v as UInt8:        return Node.uint8(v)
        case let v as UInt:         return Node.uint(v)
        case _ as NSNull:           return Node.null
        case let v as [String: Any]:return Node.object(Node.Object(uniqueKeysWithValues: v.map { ($0.key, Node.from($0.value)) }))
        case let v as [Any]:        return Node.array(Node.Array(v.compactMap { Node.from($0) }))
        case let v as Swift.Error:  return Node.error(Error.otherError(v), ignore: [])
        case .none:                 return Node.null
        default:                    return Node.error(Error.typeMismatch("unknow \(String(describing: value))"), ignore: [])
        }
    }
    
    @available(macOS 15.0, *)
    public static func uint128(_ value:UInt128) -> Node {
        return Node.number(value.description)
    }
    
    @available(macOS 15.0, *)
    public static func uint128<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == UInt128 {
        return Node.number(value.rawValue.description)
    }
    
    public static func uint64(_ value:UInt64) -> Node {
        return Node.number(value.description)
    }
    
    public static func uint64<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == UInt64 {
        return Node.number(value.rawValue.description)
    }
    
    public static func uint32(_ value:UInt32) -> Node {
        return Node.number(value.description)
    }
    
    public static func uint32<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == UInt32 {
        return Node.number(value.rawValue.description)
    }
    
    public static func uint16(_ value:UInt16) -> Node {
        return Node.number(value.description)
    }
    
    public static func uint16<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == UInt16 {
        return Node.number(value.rawValue.description)
    }
    
    public static func uint8(_ value:UInt8) -> Node {
        return Node.number(value.description)
    }
    
    public static func uint8<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == UInt8 {
        return Node.number(value.rawValue.description)
    }
    
    public static func uint(_ value:UInt) -> Node {
        return Node.number(value.description)
    }
    
    public static func uint<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == UInt {
        return Node.number(value.rawValue.description)
    }
    
    @available(macOS 15.0, *)
    public static func int128(_ value:Int128) -> Node {
        return Node.number(value.description)
    }
    
    @available(macOS 15.0, *)
    public static func int128<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Int128 {
        return Node.number(value.rawValue.description)
    }
    
    public static func int64(_ value:Int64) -> Node {
        return Node.number(value.description)
    }
    
    public static func int64<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Int64 {
        return Node.number(value.rawValue.description)
    }
    
    public static func int32(_ value:Int32) -> Node {
        return Node.number(value.description)
    }
    
    public static func int32<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Int32 {
        return Node.number(value.rawValue.description)
    }
    
    public static func int16(_ value:Int16) -> Node {
        return Node.number(value.description)
    }
    
    public static func int16<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Int16 {
        return Node.number(value.rawValue.description)
    }
    
    public static func int8(_ value:Int8) -> Node {
        return Node.number(value.description)
    }
    
    public static func int8<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Int8 {
        return Node.number(value.rawValue.description)
    }
    
    public static func char(_ value:CChar) -> Node {
        return Node(.string(String(value)))
    }
    
    public static func char<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == CChar {
        return Node(.string(String(value.rawValue)))
    }
    
    public static func int(_ value:Int) -> Node {
        return Node.number(value.description)
    }
    
    public static func int<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Int {
        return Node.number(value.rawValue.description)
    }
    
    public static func double(_ value:Double) -> Node {
        return Node.number(value.description)
    }
    
    public static func double<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Double {
        return Node.number(value.rawValue.description)
    }
    
    public static func float(_ value:Float) -> Node {
        return Node.number(value.description)
    }
    
    public static func decimal<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Decimal {
        return Node.number(value.rawValue.description)
    }
    
    public static func decimal(_ value:Decimal) -> Node {
        return Node.number(value.description)
    }
    
    public static func int<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == Float {
        return Node.number(value.rawValue.description)
    }
    
    public static func text(_ value:String?) -> Node {
        if let text = value {
            return Node.string(text)
        }
        return Node.null
    }
    
    public static func text<T>(_ value:T) -> Node where T : RawRepresentable, T.RawValue == String {
        return Node.string(value.rawValue)
    }
    
    public static func text<T>(_ value:T) -> Node where T : CustomStringConvertible {
        return Node.string(value.description)
    }
}

// MARK: - 强转成其他值
extension Node {
    
    public var asDecimal: Decimal {
        if case let .number(number) = rawValue,
           let value = try? Decimal(number, format: .number, lenient: true) {
            return value
        }
        return 0
    }
    
    public var asFloat: Float {
        Float(asDouble)
    }
    
    public var asDouble: Double {
        if case let .number(number) = rawValue,
           let value = try? Double(number, format: .number, lenient: true) {
            return value
        }
        return 0.0
    }
    
    @available(macOS 15.0, *)
    public var asInt128: Int128 {
        let doubleValue = asDouble
        if  doubleValue >= Double(Int128.max) { return Int128.max }
        if  doubleValue <= Double(Int128.min) { return Int128.min }
        if case let .number(number) = rawValue,
           let value = Int128(number) {
            return value
        }
        return 0
    }
    
    @available(macOS 15.0, *)
    public var asUInt128: UInt128 {
        let doubleValue = asDouble
        if  doubleValue >= Double(UInt128.max) { return UInt128.max }
        if case let .number(number) = rawValue,
           let value = UInt128(number) {
            return value
        }
        return 0
    }
    
    public var asInt64: Int64 {
        let doubleValue = asDouble
        if  doubleValue >= Double(Int64.max) { return Int64.max }
        if  doubleValue <= Double(Int64.min) { return Int64.min }
        if case let .number(number) = rawValue,
           let value = try? Int64(number, format: .number, lenient: true) {
            return value
        }
        return 0
    }
    
    public var asUInt64: UInt64 {
        let doubleValue = asDouble
        if  doubleValue >= Double(UInt64.max) { return UInt64.max }
        if case let .number(number) = rawValue,
           let value = try? UInt64(number, format: .number, lenient: true) {
            return value
        }
        return 0
    }
    
    public var asCChar: CChar {
        CChar(truncatingIfNeeded: asInt64)
    }
    
    public var asInt8: Int8 {
        Int8(truncatingIfNeeded: asInt64)
    }

    public var asUInt8: UInt8 {
        UInt8(truncatingIfNeeded: asUInt64)
    }

    public var asInt16: Int16 {
        Int16(truncatingIfNeeded: asInt64)
    }

    public var asUInt16: UInt16 {
        UInt16(truncatingIfNeeded: asUInt64)
    }

    public var asInt32: Int32 {
        Int32(truncatingIfNeeded: asInt64)
    }

    public var asUInt32: UInt32 {
        UInt32(truncatingIfNeeded: asUInt64)
    }

    public var bool: Bool {
        asDouble != 0
    }

    public var asInt: Int {
        Int(truncatingIfNeeded: asInt64)
    }

    public var asUInt: UInt {
        UInt(truncatingIfNeeded: asUInt64)
    }
    
    public var asString: String {
        toString(default: "")
    }
}

// MARK: - 转化成其他值
extension Node {
    
    public func toString(
        `default` defaultValue: @autoclosure () throws -> String
    ) rethrows -> String {
        switch rawValue {
        case .string(let s): return s
        case .number(let n): return n.description
        case .bool(let b): return b ? "true" : "false"
//        case .null: return try defaultValue()
        default: return try defaultValue()
        }
    }
    
    public func toString() throws -> String {
        switch rawValue {
        case .string(let s): return s
        case .number(let n): return n.description
        case .bool(let b): return b ? "true" : "false"
//        case .null: return "null"
        default: throw Error.typeMismatch("Expected string, got \(self)")
        }
    }
    
    public func toBool() -> Bool? {
        if case .number(let value) = rawValue {
            return Double(value) != 0
        }
        if case .bool(let value) = rawValue {
            return value
        }
        if case .string(let value) = rawValue {
            switch value {
            case "true":    return true
            case "false":   return false
            default:        return nil
            }
        }
        return nil
    }
    
    public func toBool(
        `default` defaultValue: @autoclosure () throws -> Bool
    ) rethrows -> Bool {
        if case .number(let value) = rawValue {
            return Double(value) != 0.0
        }
        if case .bool(let value) = rawValue {
            return value
        }
        if case .string(let value) = rawValue {
            switch value {
            case "true":    return true
            case "false":   return false
            default:        return try defaultValue()
            }
        }
        return try defaultValue()
    }
    
    public func toDecimal() -> Decimal? {
        if case .number(let value) = rawValue {
            return try? Decimal(value, format: .number, lenient: true)
        }
        return nil
    }
    
    public func toDecimal(
        `default` defaultValue: @autoclosure () throws -> Decimal
    ) rethrows -> Decimal {
        if case .number(let value) = rawValue,
            let decimal = try? Decimal(value, format: .number, lenient: true) {
            return decimal
        }
        return try defaultValue()
    }
    
    public func toDouble() -> Double? {
        if case .number(let value) = rawValue {
            return try? Double(value, format: .number, lenient: true)
        }
        return nil
    }
    
    public func toDouble(
        `default` defaultValue: @autoclosure () throws -> Double
    ) rethrows -> Double {
        if case .number(let value) = rawValue,
            let result = try? Double(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toFloat() -> Float? {
        if case .number(let value) = rawValue,
           let float = try? Float(value, format: .number, lenient: true) {
            return float
        }
        return nil
    }
    
    public func toFloat(
        `default` defaultValue: @autoclosure () throws -> Float
    ) rethrows -> Float {
        if case .number(let value) = rawValue,
           let float = try? Float(value, format: .number, lenient: true) {
            return float
        }
        return try defaultValue()
    }
    
    @available(macOS 15.0, *)
    public func toInt128() -> Int128? {
        if case .number(let value) = rawValue,
           let result = Int128(value) {
            return result
        }
        return nil
    }
    
    @available(macOS 15.0, *)
    public func toInt128(
        `default` defaultValue: @autoclosure () throws -> Int128
    ) rethrows -> Int128 {
        if case .number(let value) = rawValue,
           let result = Int128(value) {
            return result
        }
        return try defaultValue()
    }
    
    @available(macOS 15.0, *)
    public func toUInt128() -> UInt128? {
        if case .number(let value) = rawValue,
           let result = UInt128(value) {
            return result
        }
        return nil
    }
    
    @available(macOS 15.0, *)
    public func toUInt128(
        `default` defaultValue: @autoclosure () throws -> UInt128
    ) rethrows -> UInt128 {
        if case .number(let value) = rawValue,
           let result = UInt128(value) {
            return result
        }
        return try defaultValue()
    }
    
    public func toInt64() -> Int64? {
        if case .number(let value) = rawValue,
           let result = try? Int64(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toInt64(
        `default` defaultValue: @autoclosure () throws -> Int64
    ) rethrows -> Int64 {
        if case .number(let value) = rawValue,
           let result = try? Int64(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toUInt64() -> UInt64? {
        if case .number(let value) = rawValue,
           let result = try? UInt64(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toUInt64(
        `default` defaultValue: @autoclosure () throws -> UInt64
    ) rethrows -> UInt64 {
        if case .number(let value) = rawValue,
           let result = try? UInt64(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toInt32() -> Int32? {
        if case .number(let value) = rawValue,
           let result = try? Int32(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toInt32(
        `default` defaultValue: @autoclosure () throws -> Int32
    ) rethrows -> Int32 {
        if case .number(let value) = rawValue,
           let result = try? Int32(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toUInt32() -> UInt32? {
        if case .number(let value) = rawValue,
           let result = try? UInt32(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toUInt32(
        `default` defaultValue: @autoclosure () throws -> UInt32
    ) rethrows -> UInt32 {
        if case .number(let value) = rawValue,
           let result = try? UInt32(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toInt16() -> Int16? {
        if case .number(let value) = rawValue,
           let result = try? Int16(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toInt16(
        `default` defaultValue: @autoclosure () throws -> Int16
    ) rethrows -> Int16 {
        if case .number(let value) = rawValue,
           let result = try? Int16(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toUInt16() -> UInt16? {
        if case .number(let value) = rawValue,
           let result = try? UInt16(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toUInt16(
        `default` defaultValue: @autoclosure () throws -> UInt16
    ) rethrows -> UInt16 {
        if case .number(let value) = rawValue,
           let result = try? UInt16(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toInt8() -> Int8? {
        if case .number(let value) = rawValue,
           let result = try? Int8(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toInt8(
        `default` defaultValue: @autoclosure () throws -> Int8
    ) rethrows -> Int8 {
        if case .number(let value) = rawValue,
           let result = try? Int8(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toUInt8() -> UInt8? {
        if case .number(let value) = rawValue,
           let result = try? UInt8(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toUInt8(
        `default` defaultValue: @autoclosure () throws -> UInt8
    ) rethrows -> UInt8 {
        if case .number(let value) = rawValue,
           let result = try? UInt8(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
    
    public func toCChar() -> CChar? {
        if case .number(let value) = rawValue,
           let result = try? CChar(value, format: .number, lenient: true) {
            return result
        }
        return nil
    }
    
    public func toCChar(
        `default` defaultValue: @autoclosure () throws -> CChar
    ) rethrows -> CChar {
        if case .number(let value) = rawValue,
           let result = try? CChar(value, format: .number, lenient: true) {
            return result
        }
        return try defaultValue()
    }
}

extension String {
    public var asNode: Node { Node.string(self) }
}
extension FixedWidthInteger {
    public var asNode: Node { Node.number(description) }
}
extension Decimal {
    public var asNode: Node { Node.number(description) }
}
extension Double {
    public var asNode: Node { Node.number(description) }
}
extension Float {
    public var asNode: Node { Node.number(description) }
}
extension Bool {
    public var asNode: Node { Node.bool(self) }
}
extension NSNull {
    public var asNode: Node { Node.null }
}

