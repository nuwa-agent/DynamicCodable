# JSON 模块

## 功能简介

JSON 模块是 Nuwa 项目中 JSON 格式与 `Node` 树之间的薄桥接层。它本身不定义任何新的类、结构体或枚举——而是通过 `extension Node` 提供两个便捷方法，内部直接复用系统的 `JSONEncoder` / `JSONDecoder`。

通过 `@_exported import DynamicCodable`，使用者只需 `import JSON` 即可同时获得 `DynamicCodable` 模块的所有类型。

## 文件结构

```
Sources/JSON/
└── Json.swift    # Node 的 JSON 编解码扩展方法
```

## 使用方法

### 从 JSON Data 解析为 Node

```swift
import JSON

let jsonData = """
{"name": "Alice", "age": 30}
""".data(using: .utf8)!

let node = try Node.prase(json: jsonData)
print(node.name)  // "Alice"
print(node.age)   // "30"
```

### 将 Node 序列化为 JSON Data

```swift
let node = Node.object(OrderedDictionary(uniqueKeysWithValues: [
    ("name", Node.string("Bob")),
    ("age", Node.string("25"))
]))

let jsonData = try node.serializeJSON()
let jsonString = String(data: jsonData, encoding: .utf8)!
// {"name":"Bob","age":"25"}
```

## 公开 API

| 方法 | 签名 | 说明 |
|------|------|------|
| `Node.prase(json:)` | `static func prase(json: Data) throws -> Node` | 用 JSONDecoder 将 JSON Data 解析为 Node 树 |
| `Node.serializeJSON()` | `func serializeJSON() throws -> Data` | 用 JSONEncoder 将 Node 树编码为 JSON Data |

## 依赖

- **Serialization** — Node 树数据结构 (通过 @_exported 重导出)
- **Foundation** — JSONEncoder / JSONDecoder

## 注意事项

1. 方法名 `prase` 是 `parse` 的拼写变体，需注意使用时的拼写
2. 解析与序列化采用了**不同的日期策略**：解析用 `.secondsSince1970`，序列化用 `.millisecondsSince1970`——使用时需留意日期精度
3. JSON 模块**不处理注释** (`comments` / `inlineComment`)——标准 JSON 不支持注释，注释是 YAML 等格式的专有特性
4. 底层编解码能力完全来自 `Node` 的 `Codable` 协议实现 (定义在 `Serialization` 模块)
