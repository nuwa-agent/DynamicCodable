//
//  YAMLError.swift
//  Nuwa
//
//  YAML 解析和序列化过程中的错误类型定义
//

import Foundation

/// YAML 解析/序列化过程中可能发生的错误
public enum YAMLError: Swift.Error {
    /// 语法错误，包含行号信息
    case syntaxError(String, line: Int)
    /// 缩进错误
    case indentationError(String, line: Int)
    /// 类型转换错误
    case typeMismatch(String)
    /// 不支持的 YAML 特性
    case unsupported(String, line: Int)
    /// 文件末尾意外结束
    case unexpectedEndOfFile
    /// 编码错误
    case encodingError(String)
}

extension YAMLError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .syntaxError(msg, line):
            return "YAML 语法错误（第\(line + 1)行）: \(msg)"
        case let .indentationError(msg, line):
            return "YAML 缩进错误（第\(line + 1)行）: \(msg)"
        case let .typeMismatch(msg):
            return "YAML 类型不匹配: \(msg)"
        case let .unsupported(msg, line):
            return "YAML 不支持的特性（第\(line + 1)行）: \(msg)"
        case .unexpectedEndOfFile:
            return "YAML 文件意外结束"
        case let .encodingError(msg):
            return "YAML 编码错误: \(msg)"
        }
    }
}

extension YAMLError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
