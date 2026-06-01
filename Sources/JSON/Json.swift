//
//  Json.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/5.
//

@_exported import DynamicCodable

import Foundation

extension Node {
    
    public static func prase(
        json: Data,
        config: (JSONDecoder) throws -> Void = {
            decoder in
            decoder.dateDecodingStrategy = .secondsSince1970
        }
    ) throws -> Node {
        let decoder = JSONDecoder()
        try config(decoder)
        return try decoder.decode(Node.self, from: json)
    }
    
    public func serializeJSON(config: (JSONEncoder) throws -> Void = {
        encoder in
        encoder.dateEncodingStrategy = .millisecondsSince1970
    }) throws -> Data {
        let encoder = JSONEncoder()
        try config(encoder)
        return try encoder.encode(self)
    }
}
