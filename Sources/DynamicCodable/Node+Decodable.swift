//
//  Node+Decodable.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/4.
//

extension Node: Decodable {
    
    // 用于 keyedContainer 的 CodingKey
    internal struct _CodingKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    
    public init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: _CodingKey.self) {
            // 先尝试解析成对象
            var dict = OrderedDictionary<String, Node>()
            for key in container.allKeys {
                let value = try container.decode(Node.self, forKey: key)
                dict[key.stringValue] = value
            }
            self.init(rawValue: .object(dict))
        } else if var container = try? decoder.unkeyedContainer() {
            // 再尝试解析成数组
            var list = [Node]()
            while !container.isAtEnd {
                let value = try container.decode(Node.self)
                list.append(value)
            }
            self.init(rawValue: .array(list))
        } else {
            // 最后尝试解析成单值
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self.init(rawValue: .null)
            } else if let value = try? container.decode(Bool.self) {
                self.init(rawValue: .bool(value))
            } else if let value = try? container.decode(Int.self) {
                self.init(rawValue: .number(value.description))
            } else if let value = try? container.decode(Double.self) {
                self.init(rawValue: .number(value.description))
            } else if let value = try? container.decode(String.self) {
                self.init(rawValue: .string(value))
            } else {
                throw DecodingError.typeMismatch(
                    Node.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported JSON value type"
                    )
                )
            }
        }
        
    }
}
