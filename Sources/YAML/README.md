# YAML 模块

## 功能简介

YAML 模块是 DynamicCodable 项目的 YAML 格式处理库，基于 `DynamicCodable.Node` 中间表示，实现完整的 **YAML 解析、序列化、Codable 编解码**，并支持**注释完整往返保留**。

核心能力：
- **YAMLParser** — 将 YAML 字符串解析为 `Node` 树
- **YAMLSerializer** — 将 `Node` 树序列化为 YAML 字符串（保留注释）
- **YAMLDecoder** — 将 YAML 字符串解码为任意 `Decodable` 类型
- **YAMLEncoder** — 将任意 `Encodable` 类型编码为 YAML 字符串
- **YAMLError** — 统一的错误类型

数据流：`YAML String ↔ Node ↔ Swift Codable Type`（注释可完整保留）

## 文件结构

```
Sources/YAML/
├── Yaml.swift            # 模块入口，重导出 DynamicCodable 模块
├── YAMLError.swift       # YAMLError 枚举 (6 种错误)
├── YAMLParser.swift      # YAML 字符串 → Node 树 解析器
├── YAMLSerializer.swift  # Node 树 → YAML 字符串 序列化器
├── YAMLDecoder.swift     # YAML → Swift Decodable 解码器
└── YAMLEncoder.swift     # Swift Encodable → YAML 编码器
```

## 核心类型

### YAMLParser

手写 YAML 解析器，通过缩进栈管理嵌套层级，支持块风格语法。

```swift
public struct YAMLParser {
    public init()
    public func parse(_ yaml: String) throws -> Node
}
```

**支持的语法：**
- 键值对：`key: value`
- 嵌套对象：通过缩进
- 序列：`- item`
- 注释：`# comment` (行首) 和 `key: value  # 内联注释`
- 双引号字符串：`"含特殊字符的字符串"`
- 单引号字符串：`'literal string'`
- 布尔值：`true/false/yes/no/on/off`
- 空值：`null/~`
- 文档分隔符：`---` / `...`
- 块标量：`|` (保留换行) 和 `>` (折叠换行)

### YAMLSerializer

将 Node 树序列化回 YAML 字符串，完整还原注释和多行格式。

```swift
public struct YAMLSerializer {
    public var indentCount: Int  // 缩进空格数，默认 2
    public init(indentCount: Int = 2)
    public func serialize(_ node: Node) -> String
}
```

**智能输出规则：**
- 前导注释自动还原为 `# comment`
- 内联注释还原为行尾 `  # comment`
- 含特殊字符的字符串自动加双引号
- 含换行的字符串自动使用 `|` 块标量
- 短数组智能选择流式 `[a, b, c]` 或块式 `- item`
- 数字样/布尔样的字符串自动加引号防止歧义

### YAMLDecoder

仿照 Foundation `JSONDecoder` 实现，将 YAML 字符串解码为任意 `Decodable` 类型。

```swift
public struct YAMLDecoder {
    public var userInfo: [CodingUserInfoKey: Any]
    public init()
    public func decode<T: Decodable>(_ type: T.Type, from yaml: String) throws -> T
}
```

**支持的类型：** Bool、String、Double、Float、所有 Int/UInt 变体 (8/16/32/64)、自定义 Decodable 结构体/类

**支持的布尔变体：** `true`/`false`/`yes`/`no`/`on`/`off`

### YAMLEncoder

仿照 Foundation `JSONEncoder` 实现，将任意 `Encodable` 类型编码为 YAML 字符串。

```swift
public struct YAMLEncoder {
    public var userInfo: [CodingUserInfoKey: Any]
    public init()
    public func encode<T: Encodable>(_ value: T) throws -> String
}
```

### YAMLError

```swift
public enum YAMLError: Swift.Error, CustomStringConvertible, LocalizedError {
    case syntaxError(String, line: Int)       // 语法错误
    case indentationError(String, line: Int)  // 缩进错误
    case typeMismatch(String)                 // 类型不匹配
    case unsupported(String, line: Int)       // 不支持的特性
    case unexpectedEndOfFile                  // 文件意外结束
    case encodingError(String)                // 编码错误
}
```

## 使用方法

### 快速解析

```swift
import YAML

let yaml = """
server:
  host: localhost
  port: 8080
"""

let node = try YAMLParser().parse(yaml)
print(node.server.host)  // "localhost"
print(node.server.port)  // "8080"
```

### Codable 解码

```swift
struct ServerConfig: Decodable {
    var host: String
    var port: Int
}

let config = try YAMLDecoder().decode(ServerConfig.self, from: yaml)
// config.host = "localhost", config.port = 8080
```

### Codable 编码

```swift
let config = ServerConfig(host: "prod.example.com", port: 443)
let yaml = try YAMLEncoder().encode(config)
// 输出:
// host: prod.example.com
// port: 443
```

### 注释保留

```swift
let yaml = """
# 数据库配置
host: localhost  # 主机地址
"""

let node = try YAMLParser().parse(yaml)
print(node.host.comments)       // ["数据库配置"]
print(node.host.inlineComment)  // "主机地址"

// 序列化后注释完整保留
let output = YAMLSerializer().serialize(node)
// 输出包含 "# 数据库配置" 和 "# 主机地址"
```

### 往返一致性

```swift
let original = Person(name: "Alice", age: 30)
let yaml = try YAMLEncoder().encode(original)
let decoded = try YAMLDecoder().decode(Person.self, from: yaml)
// original == decoded ✅
```

## 依赖

- **DynamicCodable** — Node 树数据结构

## 注意事项

1. YAMLParser **不支持** YAML 锚点 (`&anchor`) 和别名 (`*alias`)，遇到时会抛出 `.unsupported` 错误
2. 流式风格 (`[...]` 和 `{...}`) 支持有限，仅处理简单情况
3. 解析器为块风格优化，复杂嵌套流式风格不保证完全正确
4. 所有行号为 0-indexed 内部存储，错误描述中转为 1-indexed 显示
