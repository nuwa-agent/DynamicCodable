//
//  JSONTests.swift
//

import Testing
import Foundation
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

// MARK: - Json.Schema Validation Tests

struct JsonSchemaValidationTests {

    // ── Object ──

    @Test func testObjectValid() throws {
        let schema = Json.Schema.object(properties: [
            "name": .string(description: "姓名"),
            "age": .integer(description: "年龄"),
        ], required: ["name", "age"])
        let node: Node = .object(["name": .string("Alice"), "age": .number("30")])
        try schema.validate(node)
    }

    @Test func testObjectMissingRequiredField() throws {
        let schema = Json.Schema.object(properties: [
            "name": .string(description: "姓名"),
        ], required: ["name"])
        let node: Node = .object(["age": .number("30")])
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(node)
        }
        do {
            try schema.validate(node)
        } catch let error as Json.Schema.ValidationError {
            if case .missingRequired(field: let field, at: let path) = error {
                #expect(field == "name")
                #expect(path == "$.name")
            } else {
                Issue.record("期望 missingRequired，实际: \(error)")
            }
        }
    }

    @Test func testObjectOptionalFieldNotProvided() throws {
        let schema = Json.Schema.object(properties: [
            "name": .string(description: "姓名"),
            "nick": .string(description: "昵称"),
        ], required: ["name"])
        // 只提供必填字段，可选字段缺失应通过
        let node: Node = .object(["name": .string("Alice")])
        try schema.validate(node)
    }

    @Test func testObjectTypeMismatch() throws {
        let schema = Json.Schema.object(properties: [:])
        let node: Node = .string("not an object")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(node)
        }
    }

    @Test func testObjectNestedValidation() throws {
        let schema = Json.Schema.object(properties: [
            "user": .object(properties: [
                "name": .string(description: "姓名"),
            ], required: ["name"]),
        ], required: ["user"])
        // 嵌套对象缺少必填字段
        let node: Node = .object(["user": .object(["age": .number("30")])])
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(node)
        }
    }

    // ── String ──

    @Test func testStringValid() throws {
        let schema = Json.Schema.string(description: "名称")
        try schema.validate(.string("hello"))
    }

    @Test func testStringTypeMismatch() throws {
        let schema = Json.Schema.string(description: "名称")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("42"))
        }
    }

    @Test func testStringEnumValid() throws {
        let schema = Json.Schema.string(description: "模式", enum: ["auto", "manual"])
        try schema.validate(.string("auto"))
    }

    @Test func testStringEnumInvalid() throws {
        let schema = Json.Schema.string(description: "模式", enum: ["auto", "manual"])
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("fast"))
        }
        do {
            try schema.validate(.string("fast"))
        } catch let error as Json.Schema.ValidationError {
            if case .valueNotInEnum(field: _, allowed: let allowed, actual: let actual, at: _) = error {
                #expect(allowed == ["auto", "manual"])
                #expect(actual == "fast")
            } else {
                Issue.record("期望 valueNotInEnum，实际: \(error)")
            }
        }
    }

    @Test func testStringEnumEmptyPassesAnyValue() throws {
        // 空枚举数组不做限制
        let schema = Json.Schema.string(description: "任意字符串", enum: [])
        try schema.validate(.string("anything"))
    }

    @Test func testStringMinLengthTooShort() throws {
        let schema = Json.Schema.string(description: "查询", minLength: 3)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("ab"))
        }
    }

    @Test func testStringMinLengthExactBoundary() throws {
        let schema = Json.Schema.string(description: "查询", minLength: 3)
        // 恰好等于 minLength 应通过
        try schema.validate(.string("abc"))
    }

    @Test func testStringMaxLengthTooLong() throws {
        let schema = Json.Schema.string(description: "查询", maxLength: 5)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("abcdef"))
        }
    }

    @Test func testStringMaxLengthExactBoundary() throws {
        let schema = Json.Schema.string(description: "查询", maxLength: 5)
        // 恰好等于 maxLength 应通过
        try schema.validate(.string("abcde"))
    }

    @Test func testStringPatternValid() throws {
        let schema = Json.Schema.string(description: "邮箱", pattern: "^[a-z]+@[a-z]+\\.[a-z]+$")
        try schema.validate(.string("alice@example.com"))
    }

    @Test func testStringPatternMismatch() throws {
        let schema = Json.Schema.string(description: "邮箱", pattern: "^[a-z]+@[a-z]+\\.[a-z]+$")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("NOT-VALID"))
        }
    }

    @Test func testStringEmptyValuePassesMinLengthZero() throws {
        let schema = Json.Schema.string(description: "内容", minLength: 0)
        try schema.validate(.string(""))
    }

    // ── Number ──

    @Test func testNumberValid() throws {
        let schema = Json.Schema.number(description: "温度")
        try schema.validate(.number("25.5"))
    }

    @Test func testNumberTypeMismatch() throws {
        let schema = Json.Schema.number(description: "温度")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("25.5"))
        }
    }

    @Test func testNumberMinimumViolation() throws {
        let schema = Json.Schema.number(description: "温度", minimum: 0)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("-1"))
        }
    }

    @Test func testNumberMaximumViolation() throws {
        let schema = Json.Schema.number(description: "温度", maximum: 100)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("101"))
        }
    }

    @Test func testNumberMinExactBoundary() throws {
        let schema = Json.Schema.number(description: "温度", minimum: 0)
        try schema.validate(.number("0"))
    }

    @Test func testNumberMaxExactBoundary() throws {
        let schema = Json.Schema.number(description: "温度", maximum: 100)
        try schema.validate(.number("100"))
    }

    @Test func testNumberEnumValid() throws {
        let schema = Json.Schema.number(description: "比率", enum: [0.5, 1.0, 2.0])
        try schema.validate(.number("1"))
    }

    @Test func testNumberEnumInvalid() throws {
        let schema = Json.Schema.number(description: "比率", enum: [0.5, 1.0, 2.0])
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("3.0"))
        }
    }

    @Test func testNumberNoConstraintsPassesAnything() throws {
        let schema = Json.Schema.number(description: "任意数字")
        try schema.validate(.number("999999"))
    }

    // ── Integer ──

    @Test func testIntegerValid() throws {
        let schema = Json.Schema.integer(description: "数量")
        try schema.validate(.number("42"))
    }

    @Test func testIntegerRejectsFloat() throws {
        let schema = Json.Schema.integer(description: "数量")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("3.14"))
        }
    }

    @Test func testIntegerTypeMismatch() throws {
        let schema = Json.Schema.integer(description: "数量")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("42"))
        }
    }

    @Test func testIntegerMinViolation() throws {
        let schema = Json.Schema.integer(description: "数量", minimum: 1)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("0"))
        }
    }

    @Test func testIntegerMaxViolation() throws {
        let schema = Json.Schema.integer(description: "数量", maximum: 10)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("11"))
        }
    }

    @Test func testIntegerMinExactBoundary() throws {
        let schema = Json.Schema.integer(description: "数量", minimum: 1)
        try schema.validate(.number("1"))
    }

    @Test func testIntegerMaxExactBoundary() throws {
        let schema = Json.Schema.integer(description: "数量", maximum: 10)
        try schema.validate(.number("10"))
    }

    @Test func testIntegerEnumValid() throws {
        let schema = Json.Schema.integer(description: "级别", enum: [1, 2, 3])
        try schema.validate(.number("2"))
    }

    @Test func testIntegerEnumInvalid() throws {
        let schema = Json.Schema.integer(description: "级别", enum: [1, 2, 3])
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("5"))
        }
    }

    // ── Boolean ──

    @Test func testBooleanTrue() throws {
        let schema = Json.Schema.boolean(description: "开关")
        try schema.validate(.bool(true))
    }

    @Test func testBooleanFalse() throws {
        let schema = Json.Schema.boolean(description: "开关")
        try schema.validate(.bool(false))
    }

    @Test func testBooleanTypeMismatch() throws {
        let schema = Json.Schema.boolean(description: "开关")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("true"))
        }
    }

    @Test func testBooleanNumberMismatch() throws {
        let schema = Json.Schema.boolean(description: "开关")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("1"))
        }
    }

    // ── Array ──

    @Test func testArrayValid() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"))
        try schema.validate(.array([.string("a"), .string("b")]))
    }

    @Test func testArrayTypeMismatch() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"))
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string("not an array"))
        }
    }

    @Test func testArrayMinItemsViolation() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"), minItems: 2)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.array([.string("a")]))
        }
    }

    @Test func testArrayMinItemsExactBoundary() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"), minItems: 2)
        try schema.validate(.array([.string("a"), .string("b")]))
    }

    @Test func testArrayMaxItemsViolation() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"), maxItems: 2)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.array([.string("a"), .string("b"), .string("c")]))
        }
    }

    @Test func testArrayMaxItemsExactBoundary() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"), maxItems: 2)
        try schema.validate(.array([.string("a"), .string("b")]))
    }

    @Test func testArrayEmptyWithNoConstraints() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"))
        try schema.validate(.array([]))
    }

    @Test func testArrayElementValidationFailure() throws {
        let schema = Json.Schema.array(items: .integer(description: "数字"))
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.array([.number("1"), .string("bad")]))
        }
    }

    @Test func testArrayNestedElementPath() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"))
        do {
            try schema.validate(.array([.string("ok"), .number("bad")]))
            Issue.record("应抛出错误")
        } catch let error as Json.Schema.ValidationError {
            if case .typeMismatch(_, _, let path) = error {
                #expect(path == "$[1]")
            } else {
                Issue.record("期望 typeMismatch，实际: \(error)")
            }
        }
    }

    // ── 嵌套复合结构 ──

    @Test func testComplexNestedObject() throws {
        let schema = Json.Schema.object(properties: [
            "user": .object(properties: [
                "name": .string(description: "姓名", minLength: 1),
                "age": .integer(description: "年龄", minimum: 0, maximum: 200),
            ], required: ["name"]),
            "tags": .array(items: .string(description: "标签"), minItems: 1, maxItems: 5),
        ], required: ["user", "tags"])

        let validNode: Node = .object([
            "user": .object(["name": .string("Alice"), "age": .number("30")]),
            "tags": .array([.string("admin")]),
        ])
        try schema.validate(validNode)
    }

    @Test func testComplexNestedFailureDeepPath() throws {
        let schema = Json.Schema.object(properties: [
            "user": .object(properties: [
                "name": .string(description: "姓名"),
            ], required: ["name"]),
        ], required: ["user"])

        let node: Node = .object([
            "user": .object(["name": .number("123")]),
        ])
        do {
            try schema.validate(node)
            Issue.record("应抛出错误")
        } catch let error as Json.Schema.ValidationError {
            if case .typeMismatch(expected: let expected, _, let path) = error {
                #expect(expected == "string")
                #expect(path == "$.user.name")
            } else {
                Issue.record("期望 typeMismatch，实际: \(error)")
            }
        }
    }

    // ── Path 路径追踪 ──

    @Test func testPathTrackingForRoot() throws {
        let schema = Json.Schema.string(description: "值")
        do {
            try schema.validate(.number("1"))
        } catch let error as Json.Schema.ValidationError {
            if case .typeMismatch(_, _, let path) = error {
                #expect(path == "$")
            } else {
                Issue.record("期望 typeMismatch，实际: \(error)")
            }
        }
    }

    @Test func testPathTrackingForNestedField() throws {
        let schema = Json.Schema.object(properties: [
            "a": .object(properties: [
                "b": .boolean(description: "值"),
            ]),
        ])
        do {
            try schema.validate(.object(["a": .object(["b": .string("yes")])]))
        } catch let error as Json.Schema.ValidationError {
            if case .typeMismatch(_, _, let path) = error {
                #expect(path == "$.a.b")
            } else {
                Issue.record("期望 typeMismatch，实际: \(error)")
            }
        }
    }

    @Test func testPathTrackingForArrayElement() throws {
        let schema = Json.Schema.array(items: .integer(description: "数字"))
        do {
            try schema.validate(.array([.number("1"), .string("bad"), .number("3")]))
        } catch let error as Json.Schema.ValidationError {
            if case .typeMismatch(_, _, let path) = error {
                #expect(path == "$[1]")
            } else {
                Issue.record("期望 typeMismatch，实际: \(error)")
            }
        }
    }

    // ── ValidationError.description ──

    @Test func testValidationErrorDescription() throws {
        let cases: [(Json.Schema.ValidationError, String)] = [
            (.typeMismatch(expected: "string", actual: "number", at: "$.x"), "[$.x] 期望类型为 string，实际为 number"),
            (.missingRequired(field: "name", at: "$.name"), "[$.name] 必填字段 \"name\" 缺失"),
            (.valueNotInEnum(field: "$.mode", allowed: ["a", "b"], actual: "c", at: "$.mode"), "[$.mode] 字段 \"$.mode\" 值 \"c\" 不在允许值 [\"a\", \"b\"] 中"),
            (.valueOutOfRange(field: "$.n", range: ">= 0", actual: "-1", at: "$.n"), "[$.n] 字段 \"$.n\" 值 -1 超出范围 >= 0"),
            (.stringTooShort(field: "$.q", minLength: 3, actualLength: 1, at: "$.q"), "[$.q] 字段 \"$.q\" 最少 3 字符，实际 1"),
            (.stringTooLong(field: "$.q", maxLength: 5, actualLength: 10, at: "$.q"), "[$.q] 字段 \"$.q\" 最多 5 字符，实际 10"),
            (.stringPatternMismatch(field: "$.e", pattern: "^[a-z]+$", actual: "ABC", at: "$.e"), "[$.e] 字段 \"$.e\" 值 \"ABC\" 不匹配正则 ^[a-z]+$"),
            (.arrayTooShort(field: "$.arr", minItems: 2, actualCount: 1, at: "$.arr"), "[$.arr] 字段 \"$.arr\" 最少 2 个元素，实际 1"),
            (.arrayTooLong(field: "$.arr", maxItems: 3, actualCount: 5, at: "$.arr"), "[$.arr] 字段 \"$.arr\" 最多 3 个元素，实际 5"),
        ]
        for (error, expected) in cases {
            #expect(error.description == expected)
        }
    }

    // ── 边界：null / .error 类型 ──

    @Test func testNullTypeMismatchForObject() throws {
        let schema = Json.Schema.object(properties: [:])
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.null)
        }
    }

    @Test func testNullTypeMismatchForString() throws {
        let schema = Json.Schema.string(description: "值")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.null)
        }
    }

    @Test func testNullTypeMismatchForNumber() throws {
        let schema = Json.Schema.number(description: "值")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.null)
        }
    }

    @Test func testNullTypeMismatchForBoolean() throws {
        let schema = Json.Schema.boolean(description: "值")
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.null)
        }
    }

    @Test func testNullTypeMismatchForArray() throws {
        let schema = Json.Schema.array(items: .string(description: "元素"))
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.null)
        }
    }

    // ── 边界：integer 传入负数 ──

    @Test func testIntegerNegativeValue() throws {
        let schema = Json.Schema.integer(description: "偏移", minimum: -100, maximum: 100)
        try schema.validate(.number("-50"))
    }

    @Test func testIntegerNegativeMinBoundary() throws {
        let schema = Json.Schema.integer(description: "偏移", minimum: -100)
        try schema.validate(.number("-100"))
    }

    @Test func testIntegerBelowNegativeMin() throws {
        let schema = Json.Schema.integer(description: "偏移", minimum: -100)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.number("-101"))
        }
    }

    // ── 边界：number 传入科学计数法 ──

    @Test func testNumberScientificNotation() throws {
        let schema = Json.Schema.number(description: "值")
        // "1e2" 解析为 100.0，应通过
        try schema.validate(.number("1e2"))
    }

    // ── 边界：空字符串 ──

    @Test func testStringEmptyPassesWithoutConstraints() throws {
        let schema = Json.Schema.string(description: "值")
        try schema.validate(.string(""))
    }

    @Test func testStringEmptyFailsMinLengthOne() throws {
        let schema = Json.Schema.string(description: "值", minLength: 1)
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(.string(""))
        }
    }

    // ── 边界：object 有额外未定义字段 ──

    @Test func testObjectExtraFieldsIgnored() throws {
        let schema = Json.Schema.object(properties: [
            "name": .string(description: "姓名"),
        ], required: ["name"])
        // 提供额外字段应通过（Schema 只校验定义的字段）
        let node: Node = .object([
            "name": .string("Alice"),
            "extra": .string("ignored"),
        ])
        try schema.validate(node)
    }

    // ── 边界：object 空 required 空 properties ──

    @Test func testObjectEmptySchema() throws {
        let schema = Json.Schema.object(properties: [:], required: [])
        try schema.validate(.object([:]))
    }

    // ── 边界：数组嵌套对象校验 ──

    @Test func testArrayOfObjects() throws {
        let schema = Json.Schema.array(items: .object(properties: [
            "id": .integer(description: "ID"),
        ], required: ["id"]))

        let valid: Node = .array([
            .object(["id": .number("1")]),
            .object(["id": .number("2")]),
        ])
        try schema.validate(valid)

        let invalid: Node = .array([
            .object(["id": .number("1")]),
            .object(["name": .string("oops")]),
        ])
        #expect(throws: Json.Schema.ValidationError.self) {
            try schema.validate(invalid)
        }
    }

    // ── Schema 编码往返后校验 ──

    @Test func testSchemaRoundTripValidate() throws {
        let original = Json.Schema.object(properties: [
            "name": .string(description: "名称", minLength: 1),
            "count": .integer(description: "数量", minimum: 0, maximum: 100),
        ], required: ["name"])

        // 编码为 JSON
        let data = try JSONEncoder().encode(original)
        // 解码还原
        let decoded = try JSONDecoder().decode(Json.Schema.self, from: data)

        // 用解码后的 Schema 校验数据
        let valid: Node = .object(["name": .string("test"), "count": .number("50")])
        try decoded.validate(valid)

        let invalid: Node = .object(["count": .number("50")])
        #expect(throws: Json.Schema.ValidationError.self) {
            try decoded.validate(invalid)
        }
    }
}
