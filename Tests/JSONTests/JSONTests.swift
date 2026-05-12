//
//  JSONTests.swift
//

import Testing
import DynamicCodable
@testable import JSON

struct JSONTests {

    @Test func testParseJSON() throws {
        let jsonData = """
        {"name": "Alice", "age": 30, "active": true}
        """.data(using: .utf8)!
        let node = try Node.prase(json: jsonData)
        #expect(node["name"].stringValue == "Alice")
        #expect(node["age"].stringValue == "30")
        #expect(node["active"].boolValue == true)
    }

    @Test func testParseNestedJSON() throws {
        let jsonData = """
        {"server": {"host": "localhost", "port": 8080}}
        """.data(using: .utf8)!
        let node = try Node.prase(json: jsonData)
        #expect(node["server"]["host"].stringValue == "localhost")
        #expect(node["server"]["port"].stringValue == "8080")
    }

    @Test func testParseJSONArray() throws {
        let jsonData = """
        {"items": [1, 2, 3]}
        """.data(using: .utf8)!
        let node = try Node.prase(json: jsonData)
        #expect(node["items"][0].stringValue == "1")
        #expect(node["items"][1].stringValue == "2")
        #expect(node["items"][2].stringValue == "3")
    }

    @Test func testSerializeJSON() throws {
        var dict = OrderedDictionary<String, Node>()
        dict["name"] = Node(.string("Bob"))
        dict["age"] = Node(.number("25"))
        let node = Node(.object(dict))
        let data = try node.serializeJSON()
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("Bob"))
        #expect(json.contains("25"))
    }

    @Test func testRoundTrip() throws {
        let jsonData = """
        {"key": "value", "num": 42}
        """.data(using: .utf8)!
        let node = try Node.prase(json: jsonData)
        let data = try node.serializeJSON()
        let node2 = try Node.prase(json: data)
        #expect(node2["key"].stringValue == "value")
        #expect(node2["num"].stringValue == "42")
    }

    @Test func testParseNull() throws {
        let jsonData = """
        {"value": null}
        """.data(using: .utf8)!
        let node = try Node.prase(json: jsonData)
        #expect(node["value"].isNull)
    }

    @Test func testParseBool() throws {
        let jsonData = """
        {"flag": true}
        """.data(using: .utf8)!
        let node = try Node.prase(json: jsonData)
        #expect(node["flag"].boolValue == true)
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
