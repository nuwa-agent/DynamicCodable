//
//  YAMLTests.swift
//

import Testing
import DynamicCodable
@testable import YAML

struct YAMLBasicTests {

    @Test func testParseKeyValue() throws {
        let yaml = "key: value"
        let node = try YAMLParser().parse(yaml)
        #expect(node["key"].stringValue == "value")
    }

    @Test func testParseNested() throws {
        let yaml = """
        server:
          host: localhost
          port: 8080
        """
        let node = try YAMLParser().parse(yaml)
        #expect(node["server"]["host"].stringValue == "localhost")
        #expect(node["server"]["port"].stringValue == "8080")
    }

    @Test func testParseBool() throws {
        let yaml = "active: true"
        let node = try YAMLParser().parse(yaml)
        #expect(node["active"].boolValue == true)
    }

    @Test func testParseNumber() throws {
        let yaml = "count: 42"
        let node = try YAMLParser().parse(yaml)
        #expect(node["count"].stringValue == "42")
    }

    @Test func testParseNull() throws {
        let yaml = "value: null"
        let node = try YAMLParser().parse(yaml)
        #expect(node["value"].isNull)
    }
}

struct YAMLCommentTests {

    @Test func testLeadingComment() throws {
        let yaml = """
        # This is a comment
        key: value
        """
        let node = try YAMLParser().parse(yaml)
        #expect(node["key"].comments == ["This is a comment"])
    }

    @Test func testInlineComment() throws {
        let yaml = """
        key: value  # inline comment
        """
        let node = try YAMLParser().parse(yaml)
        #expect(node["key"].inlineComment == "inline comment")
    }

    @Test func testMultipleLeadingComments() throws {
        let yaml = """
        # Line 1
        # Line 2
        key: value
        """
        let node = try YAMLParser().parse(yaml)
        #expect(node["key"].comments == ["Line 1", "Line 2"])
    }

    @Test func testCommentsPreservedAfterSerialize() throws {
        let yaml = """
        # comment
        key: value  # inline
        """
        let node = try YAMLParser().parse(yaml)
        let serialized = YAMLSerializer().serialize(node)
        #expect(serialized.contains("comment"))
        #expect(serialized.contains("inline"))
    }
}

struct YAMLSerializerTests {

    @Test func testSerializeRoundtrip() throws {
        let yaml = """
        name: Alice
        age: 30
        """
        let node = try YAMLParser().parse(yaml)
        let serialized = YAMLSerializer().serialize(node)
        let node2 = try YAMLParser().parse(serialized)
        #expect(node2["name"].stringValue == "Alice")
        #expect(node2["age"].stringValue == "30")
    }

    @Test func testSerializeNested() throws {
        let yaml = """
        server:
          host: localhost
          port: 8080
        """
        let node = try YAMLParser().parse(yaml)
        let serialized = YAMLSerializer().serialize(node)
        let node2 = try YAMLParser().parse(serialized)
        #expect(node2["server"]["host"].stringValue == "localhost")
        #expect(node2["server"]["port"].stringValue == "8080")
    }
}

struct YAMLCodecTests {

    @Test func testDecodeStruct() throws {
        let yaml = """
        name: Alice
        age: 30
        """
        struct Person: Decodable {
            let name: String
            let age: Int
        }
        let person = try YAMLDecoder().decode(Person.self, from: yaml)
        #expect(person.name == "Alice")
        #expect(person.age == 30)
    }

    @Test func testEncodeStruct() throws {
        struct Person: Encodable, Decodable {
            let name: String
            let age: Int
        }
        let person = Person(name: "Bob", age: 25)
        let yaml = try YAMLEncoder().encode(person)
        let decoded = try YAMLDecoder().decode(Person.self, from: yaml)
        #expect(decoded.name == "Bob")
        #expect(decoded.age == 25)
    }

    @Test func testDecodeNodeDirect() throws {
        let yaml = """
        key: value
        """
        let node = try YAMLDecoder().decode(Node.self, from: yaml)
        #expect(node["key"].stringValue == "value")
    }
}

extension Node {
    fileprivate var stringValue: String {
        if case .string(let v) = rawValue { return v }
        if case .number(let v) = rawValue { return v }
        return ""
    }
    fileprivate var boolValue: Bool {
        if case .bool(let v) = rawValue { return v }
        return false
    }
    fileprivate var isNull: Bool {
        if case .null = rawValue { return true }
        return false
    }
}
