//
//  Node+Subscript.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/4.
//
import Foundation

extension Node {

    // MARK: - 下标访问
    /// 字符串下标访问（用于访问对象属性）
    @inlinable
    @inline(__always)
    public subscript(key: String) -> Node {
        get {
            switch rawValue {
            case .error(let error, var ignorePath):
                ignorePath.append(key)
                return Node(rawValue: .error(error, ignore: ignorePath))
            case .object(let obj):
                return obj[key] ?? Node.null
            case .array(let list):
                if let index = Int(key) {
                    return list.indices.contains(index) ? list[index] :
                    Node(rawValue: .error(Error.outOfRange(index), ignore: []))
                }
                fallthrough
            default:
                return Node(rawValue: .error(.notContains(key), ignore: []))
            }
        }
        set {
            switch rawValue {
            case .null:
                rawValue = .object(OrderedDictionary<String, Node>(
                    dictionaryLiteral: (key, newValue)
                ))
            case .object(var obj):
                if let index = obj.index(forKey: key) {
                    obj.values[index] = newValue
                } else {
                    obj[key] = newValue
                }
                rawValue = .object(obj)
            case .array(var list):
                if let index = Int(key), list.indices.contains(index) {
                    list[index] = newValue
                    rawValue = .array(list)
                    return
                }
                fallthrough
            default:
                fatalError("error: can't set value(\(newValue) to key:(\(key)) in object:\n\(self))")
            }
        }
    }
    
    /// 整数下标访问（用于访问数组元素）
    public subscript(position: Int) -> Node {
        get {
            switch rawValue {
            case .error(let error, var ignorePath):
                ignorePath.append("Index \(position)")
                return Node(rawValue: .error(error, ignore: ignorePath))
            case .object(let obj):
                if position < obj.count {
                    return obj.values[position]
                }
                return Node(rawValue: .error(.outOfRange(position), ignore: []))
            case .array(let list):
                if position < list.count {
                    return list[position]
                }
                return Node(rawValue: .error(.outOfRange(position), ignore: []))
            default:
                return Node(rawValue: .error(.typeMismatch("json not array:\(self.debugDescription) for index:\(position)"), ignore: []))
            }
        }
        set {
            switch rawValue {
            case .object(var obj):
                if position >= obj.count {
                    fatalError("error: set index out of bounds in object:\n\(self))")
                }
                obj.values[position] = newValue
                rawValue = .object(obj)
            case .array(var list):
                if position > list.count {
                    fatalError("error: set index out of bounds in array:\n\(self))")
                }
                list[position] = newValue
                rawValue = .array(list)
            case .null where position == 0:
                rawValue = .array([newValue])
            default:
                fatalError("error: set index out of bounds in other:\n\(self))")
            }
        }
    }
    
    public mutating func append(_ element: Node) {
        if case .array(var list) = rawValue {
            list.append(element)
            rawValue = .array(list)
        } else if case .null = rawValue {
            rawValue = .array([element])
        } else {
            fatalError("error: can't append in other:\n\(self)) by element\(element)")
        }
    }
    
    @discardableResult
    public mutating func remove(forKey key: String) -> Node {
        var result = Node.null
        if case .object(var obj) = rawValue {
            result = obj.removeValue(forKey: key) ?? Node.null
            rawValue = .object(obj)
        } else {
            fatalError("error: can't remove in other:\n\(self)) by key\(key)")
        }
        return result
    }
    
    public mutating func update(_ item:Node) {
        self = item
    }
    
    public func contains(_ key:String) -> Bool {
        if case .object(let obj) = rawValue {
            return obj.keys.contains(key)
        }
        return false
    }
}


extension Node: Collection {
    
//    public typealias Element = Node
    
    public typealias Index = Int
    
    public var startIndex: Index {
        return 0
    }
    
    public var endIndex: Index {
        switch rawValue {
        case let .array(list): return list.count
        case let .object(obj): return obj.count
        default:break
        }
        return 0
    }
    
    public typealias SubSequence = ArraySlice<Node>
    
    public subscript(bounds: Range<Index>) -> ArraySlice<Node> {
        get {
            switch rawValue {
            case let .array(list): return list[bounds]
            case let .object(obj): return obj.values.elements[bounds]
            default: break
            }
            return []
        }
        set {
            switch rawValue {
            case var .array(list):
                list[bounds] = newValue
                rawValue = .array(list)
            case var .object(obj):
                for i in 0..<bounds.count {
                    obj.values[i + bounds.startIndex] = newValue[i]
                }
                rawValue = .object(obj)
            default: break
            }
        }
    }
    
    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Index) -> Index {
        return i + 1
    }
    
    /// Replaces the given index with its successor.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    public func formIndex(after i: inout Index) {
//        if i >= endIndex {
//            fatalError("index out of range:\(startIndex..<endIndex)")
//        }
        i += 1
    }
}

