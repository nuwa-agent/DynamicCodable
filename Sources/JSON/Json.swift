//
//  Json.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/5.
//

@_exported import DynamicCodable

import Foundation

extension Node {
        
    public static func prase(json: Data) throws -> Node {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(Node.self, from: json)
    }
    
    public func serializeJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(self)
    }
}
