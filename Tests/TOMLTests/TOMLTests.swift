//
//  TOMLTests.swift
//  TOMLTests
//

import Testing
import DynamicCodable
@testable import TOML

// MARK: - 基本 TOML 解析测试

struct TOMLBasicTests {

    @Test func testParseKeyValue() throws {
        let toml = "key = \"value\""
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["key"].stringValue == "value")
    }

    @Test func testParseInteger() throws {
        let toml = "num = 42"
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["num"].stringValue == "42")
    }

    @Test func testParseBoolean() throws {
        let toml = """
        a = true
        b = false
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["a"].boolValue == true)
        #expect(node["b"].boolValue == false)
    }

    @Test func testParseFloat() throws {
        let toml = "pi = 3.14"
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["pi"].stringValue == "3.14")
    }

    @Test func testParseMultipleKeys() throws {
        let toml = """
        name = "Alice"
        age = 30
        active = true
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["name"].stringValue == "Alice")
        #expect(node["age"].stringValue == "30")
        #expect(node["active"].boolValue == true)
    }

    @Test func testParseEmpty() throws {
        let toml = ""
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node.isNull || node.isObject)
    }
}

// MARK: - 注释测试

struct TOMLCommentTests {

    @Test func testLeadingComment() throws {
        let toml = """
        # 这是注释
        key = "value"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["key"].comments == ["这是注释"])
    }

    @Test func testInlineComment() throws {
        let toml = """
        key = "value"  # 行内注释
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["key"].inlineComment == "行内注释")
    }

    @Test func testMultipleLeadingComments() throws {
        let toml = """
        # 第一行
        # 第二行
        key = "value"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["key"].comments == ["第一行", "第二行"])
    }

    @Test func testCommentNotMixed() throws {
        let toml = """
        # 属于 key1
        key1 = "value1"
        # 属于 key2
        key2 = "value2"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["key1"].comments == ["属于 key1"])
        #expect(node["key2"].comments == ["属于 key2"])
    }

    @Test func testCommentBeforeTable() throws {
        let toml = """
        # 表注释
        [table]
        key = "value"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["table"].comments == ["表注释"])
    }
}

// MARK: - 表解析测试

struct TOMLTableTests {

    @Test func testBasicTable() throws {
        let toml = """
        [table]
        key = "value"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["table"]["key"].stringValue == "value")
    }

    @Test func testNestedTable() throws {
        let toml = """
        [a.b]
        key = "value"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["a"]["b"]["key"].stringValue == "value")
    }

    @Test func testMultipleTables() throws {
        let toml = """
        [a]
        key1 = "v1"

        [b]
        key2 = "v2"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["a"]["key1"].stringValue == "v1")
        #expect(node["b"]["key2"].stringValue == "v2")
    }
}

// MARK: - 表数组测试

struct TOMLArrayTableTests {

    @Test func testArrayOfTables() throws {
        let toml = """
        [[products]]
        name = "Hammer"

        [[products]]
        name = "Nail"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["products"][0]["name"].stringValue == "Hammer")
        #expect(node["products"][1]["name"].stringValue == "Nail")
    }

    @Test func testArrayTableWithFields() throws {
        let toml = """
        [[fruits]]
        name = "apple"

        [[fruits]]
        name = "banana"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["fruits"][0]["name"].stringValue == "apple")
        #expect(node["fruits"][1]["name"].stringValue == "banana")
    }
}

// MARK: - TOML 值类型测试

struct TOMLValueTests {

    @Test func testStringEscapes() throws {
        let toml = """
        str = "hello\\nworld"
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["str"].stringValue == "hello\nworld")
    }

    @Test func testLiteralString() throws {
        let toml = """
        str = 'hello\\nworld'
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        // Literal strings do not interpret escapes
        #expect(node["str"].stringValue == "hello\\nworld")
    }

    @Test func testIntegerTypes() throws {
        let toml = """
        hex = 0xDEAD
        oct = 0o777
        bin = 0b1010
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["hex"].stringValue == "0xDEAD")
        #expect(node["oct"].stringValue == "0o777")
        #expect(node["bin"].stringValue == "0b1010")
    }

    @Test func testArray() throws {
        let toml = """
        arr = [1, 2, 3]
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["arr"][0].stringValue == "1")
        #expect(node["arr"][1].stringValue == "2")
        #expect(node["arr"][2].stringValue == "3")
    }

    @Test func testEmptyArray() throws {
        let toml = """
        arr = []
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["arr"].isArray)
    }
}

// MARK: - 序列化测试

struct TOMLSerializerTests {

    @Test func testSerializeRoundtrip() throws {
        let toml = """
        name = "Alice"
        age = 30
        active = true
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        let serialized = TOMLSerializer().serialize(node)
        let node2 = try parser.parse(serialized)
        #expect(node2["name"].stringValue == "Alice")
        #expect(node2["age"].stringValue == "30")
        #expect(node2["active"].boolValue == true)
    }

    @Test func testSerializeTableRoundtrip() throws {
        let toml = """
        [server]
        host = "localhost"
        port = 8080
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        let serialized = TOMLSerializer().serialize(node)
        let node2 = try parser.parse(serialized)
        #expect(node2["server"]["host"].stringValue == "localhost")
        #expect(node2["server"]["port"].stringValue == "8080")
    }

    @Test func testSerializeWithComments() throws {
        let toml = """
        # 这是名字
        name = "Alice"  # 内联
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        let serialized = TOMLSerializer().serialize(node)
        #expect(serialized.contains("这是名字"))
        #expect(serialized.contains("内联"))
        // 验证往返
        let node2 = try parser.parse(serialized)
        #expect(node2["name"].stringValue == "Alice")
    }

    @Test func testSerializeArrayTable() throws {
        let toml = """
        [[items]]
        id = 1

        [[items]]
        id = 2
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        let serialized = TOMLSerializer().serialize(node)
        let node2 = try parser.parse(serialized)
        #expect(node2["items"][0]["id"].stringValue == "1")
        #expect(node2["items"][1]["id"].stringValue == "2")
    }
}

// MARK: - 编解码器测试

struct TOMLCodecTests {

    @Test func testDecodeStruct() throws {
        let toml = """
        name = "Alice"
        age = 30
        """
        struct Person: Decodable {
            let name: String
            let age: Int
        }
        let person = try TOMLDecoder().decode(Person.self, from: toml)
        #expect(person.name == "Alice")
        #expect(person.age == 30)
    }

    @Test func testEncodeStruct() throws {
        struct Person: Encodable, Decodable {
            let name: String
            let age: Int
        }
        let person = Person(name: "Bob", age: 25)
        let toml = try TOMLEncoder().encode(person)
        let decoded = try TOMLDecoder().decode(Person.self, from: toml)
        #expect(decoded.name == "Bob")
        #expect(decoded.age == 25)
    }

    @Test func testDecodeNodeDirect() throws {
        let toml = """
        key = "value"
        """
        let node = try TOMLDecoder().decode(Node.self, from: toml)
        #expect(node["key"].stringValue == "value")
    }
}

// MARK: - 错误处理测试

struct TOMLErrorTests {

    @Test func testSyntaxError() throws {
        let toml = "key without equals"
        var parser = TOMLParser()
        #expect(throws: TOMLError.self) {
            try parser.parse(toml)
        }
    }

    @Test func testEmptyValue() throws {
        let toml = "key = "
        var parser = TOMLParser()
        #expect(throws: TOMLError.self) {
            try parser.parse(toml)
        }
    }
}

// MARK: - includeComments:false 模式测试

struct TOMLIncludeCommentsTests {

    @Test func testParserIgnoresLeadingComments() throws {
        let toml = """
        # 前导注释
        key = "value"
        """
        var parser = TOMLParser(includeComments: false)
        let node = try parser.parse(toml)
        #expect(node["key"].comments.isEmpty)
    }

    @Test func testParserIgnoresInlineComments() throws {
        let toml = """
        key = "value"  # 内联注释
        """
        var parser = TOMLParser(includeComments: false)
        let node = try parser.parse(toml)
        #expect(node["key"].inlineComment == nil)
    }

    @Test func testSerializerOmitsComments() throws {
        var node = Node(.string("value"))
        node.comments = ["前导"]
        node.inlineComment = "内联"
        var dict = OrderedDictionary<String, Node>()
        dict["key"] = node
        let parent = Node(.object(dict))
        let output = TOMLSerializer(includeComments: false).serialize(parent)
        #expect(!output.contains("#"))
    }

    @Test func testParserWithCommentsEnabledByDefault() throws {
        let toml = """
        # 前导
        key = "value"  # 内联
        """
        var parser = TOMLParser()
        let node = try parser.parse(toml)
        #expect(node["key"].comments == ["前导"])
        #expect(node["key"].inlineComment == "内联")
    }
}

// MARK: - Node 属性扩展（测试辅助）

extension Node {
    var stringValue: String {
        if case .string(let v) = rawValue { return v }
        if case .number(let v) = rawValue { return v }
        return ""
    }

    var boolValue: Bool {
        if case .bool(let v) = rawValue { return v }
        return false
    }

    var isNull: Bool {
        if case .null = rawValue { return true }
        return false
    }

    var isObject: Bool {
        if case .object = rawValue { return true }
        return false
    }

    var isArray: Bool {
        if case .array = rawValue { return true }
        return false
    }
}
