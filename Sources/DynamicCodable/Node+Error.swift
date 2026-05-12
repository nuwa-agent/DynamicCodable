//
//  Node+Error.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/4.
//

import Foundation

extension Node {
    public enum Error: Swift.Error, LocalizedError {
        case notContains(String)
        case outOfRange(Int)
        case typeMismatch(String)
        case otherError(any Swift.Error)
    }
}

extension Node.Error {
    public var localizedDescription: String {
        return description
    }
}

extension Node.Error : CustomStringConvertible {
    
    public var description: String {
        switch self {
        case let .notContains(value):
            return "object not contains `\(value)`"
        case let .outOfRange(value):
            return "index `\(value)` out of range"
        case let .typeMismatch(value):
            return "type mismatch `\(value)`"
        case let .otherError(error):
            return error.localizedDescription
        }
    }
    
}


extension Node.Error : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
        case let .notContains(value):
            return "object not contains `\(value)`"
        case let .outOfRange(value):
            return "index `\(value)` out of range"
        case let .typeMismatch(value):
            return "type mismatch `\(value)`"
        case let .otherError(error):
            return error.localizedDescription
        }
    }
    
}

extension Node.Error : Equatable {
    public static func == (lhs: Node.Error, rhs: Node.Error) -> Bool {
        switch (lhs, rhs) {
        case let (.notContains(lhsKey), .notContains(rhsKey)):
            return lhsKey == rhsKey
        case let (.outOfRange(lhsIndex), .outOfRange(rhsIndex)):
            return lhsIndex == rhsIndex
        case let (.typeMismatch(lhsType), .typeMismatch(rhsType)):
            return lhsType == rhsType
        case (.otherError, .otherError):
            // otherError 包装的 Swift.Error 可能不可 Equatable，直接返回 true 表示同种错误类型
            return true
        default:
            return false
        }
    }
}
