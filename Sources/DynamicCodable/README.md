# DynamicCodable 模块

## 功能简介

DynamicCodable 是 DynamicCodable 项目的**核心数据抽象层**，提供与格式无关的树形数据结构 `Node`，作为 JSON、YAML、TOML 等序列化格式的统一中间表示 (IR)，完整桥接 Swift 的 `Codable` 协议。

设计理念：所有格式的数据先转化为 `Node` 树，再根据需要转为目标格式或 Swift 原生类型。`Node` 额外保留注释元数据 (`comments` / `inlineComment`)，确保 YAML、TOML 等格式的"读→改→写"往返过程中注释不丢失。

## 文件结构

```
Sources/DynamicCodable/
├── Node.swift              # Node 结构体定义、Object/Array 类型别名、Equatable、dynamicMemberLookup
├── Node+Value.swift        # Node.Value 枚举 (7 种值类型)、计算属性、Equatable
├── Node+Convert.swift      # 静态工厂方法、类型检查 (isXxx)、安全转换 (toXxx)、兜底转换 (asXxx)
├── Node+Subscript.swift    # 下标访问、Collection 协议遵循、增删改操作
├── Node+Error.swift        # Node.Error 枚举 (4 种错误)、LocalizedError
├── Node+Decodable.swift    # Decodable 实现，支持从标准 JSONDecoder 解码为 Node
└── Node+Encodable.swift    # Encodable 实现，支持将 Node 编码到标准 JSONEncoder
```

## 核心类型

### 1. Node (结构体)

主树节点，使用 `@dynamicMemberLookup`，支持链式访问如 `node.server.host`。

```swift
public struct Node: Sendable {
    public typealias Object = OrderedDictionary<String, Node>
    public typealias Array  = [Node]

    public let rawValue: Value        // 实际存储的值
    public let comments: [String]     // 前导注释行 (不含 # 前缀)
    public let inlineComment: String? // 行尾注释 (不含 # 前缀)
}
```

### 2. Node.Value (枚举)

7 种值类型，覆盖常见数据形态：

| Case | 关联值 | 说明 |
|------|--------|------|
| `.null` | — | 空值 |
| `.bool(Bool)` | Bool | 布尔值 |
| `.number(String)` | String | 数字（以字符串存储保精度） |
| `.string(String)` | String | 字符串 |
| `.array([Node])` | [Node] | 数组 |
| `.object(OrderedDictionary)` | 有序字典 | 对象/映射 |
| `.error(Node.Error, ignore: [String])` | Error + 忽略路径 | 错误容器（容错访问路径） |

### 3. Node.Error (枚举)

| Case | 说明 |
|------|------|
| `.notContains(String)` | 对象中不存在该键 |
| `.outOfRange(Int)` | 数组索引越界 |
| `.typeMismatch(String)` | 访问了错误的值类型 |
| `.otherError(any Swift.Error)` | 包装任意错误 |

## 使用方法

### 创建 Node

```swift
import DynamicCodable

// 静态工厂方法
let strNode  = Node.string("hello")
let numNode  = Node.number("42")
let boolNode = Node.bool(true)
let nullNode = Node.null

// 嵌套对象
let server = Node.object(OrderedDictionary(uniqueKeysWithValues: [
    ("host", Node.string("localhost")),
    ("port", Node.number("8080"))
]))

// 数组
let items = Node.array([Node.string("a"), Node.string("b"), Node.string("c")])

// 从任意 Swift 类型创建
let node = Node.from(42)           // → .number("42")
let node2 = Node.from("hello")     // → .string("hello")
let node3 = Node.from(nil)         // → .null
```

### 访问 Node

```swift
// 下标访问（支持字符串键和整数索引）
let host = server["host"]            // → .string("localhost")
let port = server["port"]            // → .number("8080")

// 动态成员查找（语法糖）
let host2 = server.host              // 等价于 server["host"]

// Collection 遍历
for item in items {
    print(item)
}

// 类型检查
node.isString    // Bool
node.isNumber    // Bool
node.isObject    // Bool
node.isArray     // Bool
node.isNull      // Bool
```

### 类型转换

```swift
// 安全转换 (返回 Optional，失败不抛错)
let s: String? = node.toString()
let i: Int?    = node.toInt()

// 带默认值的转换 (失败使用默认值)
let s2 = node.toString(default: "fallback")
let i2 = node.toInt(default: 0)

// 兜底转换 (失败返回 0/false/空字符串，适用于容错场景)
let d: Double = node.asDouble
let b: Bool   = node.asBool
```

### Codable 桥接

```swift
// Node 本身遵循 Codable，可直接用于系统编解码器
let jsonData = try JSONEncoder().encode(someNode)
let decoded  = try JSONDecoder().decode(Node.self, from: jsonData)
```

## 依赖

- **OrderedCollections** (来自 swift-collections) — 用于 `Node.Object` 有序字典，保证键插入顺序

## 注意事项

1. `.number` 内部以 `String` 存储，避免 `Double ↔ Decimal` 之间的精度损失；数值相等比较通过 `Double()` 转换进行
2. `Node+Decodable` 和 `Node+Encodable` 的标准 Codable 桥接**不保留注释元数据**；需要注释保留请使用 YAML 模块
3. 下标访问越界时 `fatalError`，错误路径访问返回 `.error` Node
