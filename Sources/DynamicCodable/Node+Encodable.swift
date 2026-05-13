//
//  Node+Encodable.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/4.
//
import Foundation

extension Node: Encodable {
    
    public func encode(to encoder: any Encoder) throws {
        
        switch rawValue {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            if #available(macOS 15.0, *), let number = Int128(value) {
                try container.encode(number)
            } else if let number = Double(value) {
                try container.encode(number)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .array(let wraps):
            var container = encoder.unkeyedContainer()
            try container.encode(contentsOf: wraps)
        case .object(let dict):
            var container = encoder.container(keyedBy: _CodingKey.self)
            for (key, node) in dict {
                try container.encode(node, forKey: _CodingKey(stringValue: key))
            }
        case .error:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
    
}
