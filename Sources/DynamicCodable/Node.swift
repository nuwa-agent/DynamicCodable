//
//  Node.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/4.
//  要理解 Serialization 先阅读`README.md`
@_exported import OrderedCollections

@dynamicMemberLookup
public struct Node: RawRepresentable, Sendable {
        
    public typealias RawValue = Value
    
    public typealias Object = OrderedDictionary<String, Node>
    
    public typealias Array = [Node]
    
    public init(
        _ value: Value,
        inlineComment: String? = nil,
        comments: [String] = []
    ) {
        rawValue = value
        self.inlineComment = inlineComment
        self.comments = comments
    }
    
    public init(rawValue: RawValue) {
        self.init(rawValue)
    }
    
    public var rawValue: RawValue

    /// Comment lines immediately preceding this key (without the "# " prefix).
//    @usableFromInline
    public var comments: [String]
    /// An inline comment on the same line as the value (without the "# " prefix), if present.
//    @usableFromInline
    public var inlineComment: String?
    
    @inlinable
    @inline(__always)
    public subscript(dynamicMember member: String) -> Node {
        self[member]
    }
}



// MARK: - Equatable

extension Node: Equatable {
    public static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}


// MARK: - CustomStringConvertible

extension Node: CustomStringConvertible {
    public var description: String {
        rawValue.description
    }
}
