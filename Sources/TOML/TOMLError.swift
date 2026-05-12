//
//  TOMLError.swift
//  Nuwa
//

import Foundation

public enum TOMLError: Swift.Error {
    case syntaxError(String, line: Int)
    case valueError(String, line: Int)
    case duplicateTable(String, line: Int)
    case duplicateKey(String, line: Int)
    case unexpectedEndOfFile
    case encodingError(String)
}

extension TOMLError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .syntaxError(msg, line):
            return "TOML 语法错误（第\(line + 1)行）: \(msg)"
        case let .valueError(msg, line):
            return "TOML 值错误（第\(line + 1)行）: \(msg)"
        case let .duplicateTable(msg, line):
            return "TOML 重复表（第\(line + 1)行）: \(msg)"
        case let .duplicateKey(msg, line):
            return "TOML 重复键（第\(line + 1)行）: \(msg)"
        case .unexpectedEndOfFile:
            return "TOML 文件意外结束"
        case let .encodingError(msg):
            return "TOML 编码错误: \(msg)"
        }
    }
}

extension TOMLError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
