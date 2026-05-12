# TOML 模块

## 功能简介

TOML 模块是 DynamicCodable 项目的 TOML 格式处理库，基于 `Node` 中间表示，实现完整的 **TOML 解析、序列化、Codable 编解码**，并支持**注释完整往返保留**。

核心能力：
- **TOMLParser** — 将 TOML v1.0 字符串解析为 `Node` 树（保留注释）
- **TOMLSerializer** — 将 `Node` 树序列化为 TOML 字符串（保留注释）
- **TOMLDecoder** — 将 TOML 字符串解码为任意 `Decodable` 类型
- **TOMLEncoder** — 将任意 `Encodable` 类型编码为 TOML 字符串
- **TOMLError** — 统一的错误类型

数据流：`TOML String ↔ Node ↔ Swift Codable Type`

## 文件结构

```
Sources/TOML/
├── Toml.swift            # 模块入口，重导出 DynamicCodable 模块
├── TOMLError.swift       # TOMLError 枚举（6 种错误）
├── TOMLParser.swift      # TOML 字符串 → Node 树 解析器
├── TOMLSerializer.swift  # Node 树 → TOML 字符串 序列化器
├── TOMLDecoder.swift     # TOML → Swift Decodable 解码器
└── TOMLEncoder.swift     # Swift Encodable → TOML 编码器
```

## 核心类型

### TOMLParser

手写 TOML v1.0 解析器，通过状态机管理键值对和表嵌套。

```swift
public struct TOMLParser {
    public init()
    public mutating func parse(_ toml: String) throws -> Node
}
```

**支持的语法：**
- 键值对：`key = "value"`
- 表头：`[table]` 和 `[a.b.c]`（嵌套表）
- 表数组：`[[array]]`
- 注释：`# comment`（行首）和 `key = "value"  # 内联注释`
- 字符串：基本字符串 `"hello"`（支持 `\n`, `\t`, `\\`, `\"`, `\uXXXX` 转义）
- 字符串：纯字符串 `'hello'`（不支持转义）
- 多行字符串：`"""..."""` 和 `'''...'''`
- 整数：十进制 `42`、十六进制 `0xDEAD`、八进制 `0o777`、二进制 `0b1010`
- 浮点数：`3.14`、`1e10`、`inf`、`nan`
- 布尔值：`true` / `false`
- 日期时间：`1979-05-27T07:32:00Z`、`1979-05-27`、`07:32:00`
- 数组：`[1, 2, 3]` 和嵌套数组
- 内联表：`key = { a = 1, b = 2 }`
- 点键：`a.b.c = value`

**注释保留规则：**
- `#` 开头的行 → 累积为 `pendingComments` → 附加到下一个键值对/表头的 `comments`
- 值后的 `# comment` → 解析为 `inlineComment`

### TOMLSerializer

将 Node 树序列化回 TOML 字符串，完整还原注释并智能组织表结构。

```swift
public struct TOMLSerializer {
    public init()
    public func serialize(_ node: Node) -> String
}
```

**智能输出规则：**
- 对象属性拆分为：根级别键值对、`[table]` 子表、`[[array]]` 表数组
- 前导注释自动还原为 `# comment`
- 内联注释还原为行尾 `  # comment`
- 含转义字符的字符串自动转义
- 多行字符串自动使用 `"""..."""` 格式
- 短数组使用单行 `[a, b, c]`，复杂数组使用多行格式
- 内联表使用 `{ key = value }` 格式

### TOMLDecoder

仿照 Foundation `JSONDecoder` 实现，将 TOML 字符串解码为任意 `Decodable` 类型。

```swift
public struct TOMLDecoder {
    public var userInfo: [CodingUserInfoKey: Any]
    public init()
    public func decode<T: Decodable>(_ type: T.Type, from toml: String) throws -> T
}
```

**支持的类型：** Bool、String、Double、Float、所有 Int/UInt 变体、自定义 Decodable 结构体/类
**特殊支持：** `decode(Node.self, from:)` 直接获取 Node 树（含注释）

### TOMLEncoder

将任意 `Encodable` 类型编码为 TOML 字符串。

```swift
public struct TOMLEncoder {
    public var userInfo: [CodingUserInfoKey: Any]
    public init()
    public func encode<T: Encodable>(_ value: T) throws -> String
}
```

### TOMLError

```swift
public enum TOMLError: Swift.Error, CustomStringConvertible, LocalizedError {
    case syntaxError(String, line: Int)       // 语法错误
    case valueError(String, line: Int)         // 值错误
    case duplicateTable(String, line: Int)    // 重复表定义
    case duplicateKey(String, line: Int)      // 重复键
    case unexpectedEndOfFile                  // 文件意外结束
    case encodingError(String)                // 编码错误
}
```

## 使用方法

### 快速解析

```swift
import TOML

let toml = """
title = "TOML Example"

[owner]
name = "Tom"
dob = 1979-05-27T07:32:00Z
"""

var parser = TOMLParser()
let node = try parser.parse(toml)
print(node.title)          // "TOML Example"
print(node.owner.name)     // "Tom"
```

### Codable 解码

```swift
struct Config: Decodable {
    var title: String
    var owner: Owner
}

struct Owner: Decodable {
    var name: String
}

let config = try TOMLDecoder().decode(Config.self, from: toml)
print(config.title)  // "TOML Example"
```

### Codable 编码

```swift
let config = Config(title: "My App", owner: Owner(name: "Alice"))
let toml = try TOMLEncoder().encode(config)
```

### 注释保留

```swift
let toml = """
# 数据库配置
host = "localhost"  # 主机地址
"""

var parser = TOMLParser()
let node = try parser.parse(toml)
print(node.host.comments)       // ["数据库配置"]
print(node.host.inlineComment)  // "主机地址"

// 序列化后注释完整保留
let output = TOMLSerializer().serialize(node)
// 输出包含 "# 数据库配置" 和 "# 主机地址"
```

### 表数组

```swift
let toml = """
[[products]]
name = "Hammer"
sku = 738594937

[[products]]
name = "Nail"
sku = 284758393
"""

var parser = TOMLParser()
let node = try parser.parse(toml)
print(node["products"][0]["name"])  // "Hammer"
print(node["products"][1]["name"])  // "Nail"
```

## 依赖

- **DynamicCodable** — Node 树数据结构

## 注意事项

1. TOML 解析器为行级解析器，不支持多行数组/内联表跨行的文件级合并
2. 表数组 `[[key]]` 的注释会关联到数组元素上，而非数组本身
3. 重复的键和重复的表定义会分别抛出 `.duplicateKey` 和 `.duplicateTable` 错误
4. 内联表（`{...}`）中不支持重复键检测（自动覆盖）
