<div align="center">

# DynamicCodable

**多格式序列化统一中间表示库 — JSON / YAML / TOML 的 Swift 解决方案**

![Swift](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift)
![Platforms](https://img.shields.io/badge/platform-macOS%20|%20iOS%20|%20Linux%20|%20Windows-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)

</div>

---

## 项目简介

**DynamicCodable** 是一个纯 Swift 实现的多格式序列化库，以**树形数据结构 `Node`** 为核心中间表示（IR），在 **JSON、YAML、TOML** 三种格式之间提供统一的序列化/反序列化能力。

核心设计理念：

- **`Node` 作为统一中间表示** — 所有格式的数据先转化为 `Node` 树，再根据需要转为目标格式或 Swift 原生类型
- **注释元数据完整保留** — `Node` 额外存储 `comments` / `inlineComment`，确保"读→改→写"往返过程中注释不丢失
- **Codable 原生桥接** — `Node` 本身遵循 `Codable`，同时提供各格式专属的 `XxxDecoder` / `XxxEncoder`，无缝对接 Swift 原生类型

---

## 功能特性

### 🎯 核心模块 (DynamicCodable)

- **`Node` 树形数据结构** — 支持 `@dynamicMemberLookup` 链式访问（`node.server.host`）
- **7 种值类型** — `.null` / `.bool` / `.number` / `.string` / `.array` / `.object` / `.error`
- **安全类型转换** — 提供 `toXxx(default:)`、`toXxx()`、`asXxx` 三级转换体系
- **`Codable` 原生遵循** — 可直接使用系统 `JSONEncoder` / `JSONDecoder` 编解码
- **`@Default` 属性包装器** — 为 Decodable 提供默认值支持

### 📄 JSON 模块

- `Node.prase(json:)` — 解析 JSON Data 为 Node 树
- `Node.serializeJSON()` — 将 Node 树序列化为 JSON Data

### 📝 YAML 模块

- **手写 YAML 解析器** — 支持缩进嵌套、块标量（`|` / `>`）、注释保留
- **完整序列化** — 智能引号、流式/块式数组自动选择
- **YAMLDecoder / YAMLEncoder** — 与 `JSONDecoder` 用法一致的 Codable 桥接

### ⚙️ TOML 模块

- **TOML v1.0 完全实现** — 支持表、表数组、内联表、日期时间等全部语法
- **注释往返保留** — 解析时保留注释，序列化时完整还原
- **TOMLDecoder / TOMLEncoder** — 与 `JSONDecoder` 用法一致的 Codable 桥接

---

## 跨平台支持

DynamicCodable **纯用 Swift 编写**，仅依赖 Foundation 框架（所有 Swift 平台可用），**没有任何平台特定代码**。

| 平台 | 支持状态 | 最低版本 |
|------|---------|---------|
| macOS | ✅ | 13.0 |
| iOS | ✅ | 16.0 |
| Linux | ✅ | 任意（需 Swift 6.2+） |
| Windows | ✅ | 任意（需 Swift 6.2+） |
| Android | ✅ | 任意（需 Swift 6.2+） |
| watchOS | ✅ | 9.0+（需自行添加 platform） |
| tvOS | ✅ | 16.0+（需自行添加 platform） |

> 如需增加 watchOS / tvOS / visionOS 支持，在 `Package.swift` 的 `platforms` 数组中添加对应条目即可。

---

## 安装

### Swift Package Manager

在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/nuwa-agent/DynamicCodable.git", from: "1.0.0"),
]
```

按需引入模块：

```swift
// 仅使用 Node 核心
.target(name: "MyTarget", dependencies: ["DynamicCodable"])

// 使用 JSON 支持
.target(name: "MyTarget", dependencies: ["JSON"])

// 使用 YAML 支持
.target(name: "MyTarget", dependencies: ["YAML"])

// 使用 TOML 支持
.target(name: "MyTarget", dependencies: ["TOML"])

// 全部引入
.target(name: "MyTarget", dependencies: ["DynamicCodable", "JSON", "YAML", "TOML"])
```

### Xcode 集成

1. File → Add Package Dependencies...
2. 搜索 `https://github.com/nuwa-agent/DynamicCodable.git`
3. 选择需要的模块（DynamicCodable / JSON / YAML / TOML）

---

## 快速开始

### 使用 Node 核心

```swift
import DynamicCodable

// 创建 Node
let config = Node.object([
    "server": Node.object([
        "host": Node.string("localhost"),
        "port": Node.number("8080"),
    ]),
    "debug": Node.bool(true),
])

// 动态成员访问
print(config.server.host)  // "localhost"
print(config.server.port)  // "8080"

// 安全类型转换
let host: String? = config.server.host.toString()
let port: Int = config.server.port.toInt(default: 0)

// 从任意 Swift 类型自动推断
let node = Node.from(42)        // Node(.number("42"))
let node2 = Node.from("hello")  // Node(.string("hello"))
let node3 = Node.from([1, 2, 3]) // Node(.array([.number("1"), ...]))
```

### JSON

```swift
import JSON

// JSON → Node
let json = """
{
    "name": "Alice",
    "age": 30,
    "skills": ["Swift", "Python"]
}
""".data(using: .utf8)!

let node = try Node.prase(json: json)
print(node.name.toString())       // "Alice"
print(node.skills[0].toString())  // "Swift"

// Node → JSON
let output = try node.serializeJSON()
print(String(data: output, encoding: .utf8)!)
```

### YAML

```swift
import YAML

// YAML → Node（保留注释）
let yaml = """
# 服务器配置
server:
  host: localhost  # 主机名
  port: 8080
"""

let node = try YAMLParser().parse(yaml)
print(node.server.host.toString())       // "localhost"
print(node.server.host.comments)         // ["服务器配置"]
print(node.server.host.inlineComment)    // "主机名"

// YAML → Decodable 类型
struct Config: Decodable {
    let host: String
    let port: Int
}

let config = try YAMLDecoder().decode(Config.self, from: yaml)
print(config.host)  // "localhost"

// Encodable → YAML
let output = try YAMLEncoder().encode(config)
print(output)
// host: localhost
// port: 8080

// 修改后序列化，注释完整保留
node.server.host = Node.string("prod.example.com")
let modified = YAMLSerializer().serialize(node)
// 输出仍包含 "# 服务器配置" 和 "# 主机名"
```

### TOML

```swift
import TOML

// TOML → Node（保留注释）
let toml = """
# TOML 配置
title = "Example"

[owner]
name = "Tom"  # 用户名
dob = 1979-05-27T07:32:00Z

[[products]]
name = "Hammer"
sku = 738594937
"""

var parser = TOMLParser()
let node = try parser.parse(toml)
print(node.title.toString())             // "Example"
print(node.owner.name.toString())        // "Tom"
print(node.owner.name.inlineComment)     // "用户名"

// TOML → Decodable 类型
struct Config: Decodable {
    let title: String
    let owner: Owner
    let products: [Product]
}

let config = try TOMLDecoder().decode(Config.self, from: toml)

// Encodable → TOML
let output = try TOMLEncoder().encode(config)
```

---

## 项目架构

```
                         ┌─────────────────────────────┐
                         │      Swift Codable 类型       │
                         └──────────┬──────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
             ┌──────────┐    ┌──────────┐    ┌──────────┐
             │YAMLDecoder│    │JSON Module│    │TOMLDecoder│
             │YAMLEncoder│    │(系统桥接)  │    │TOMLEncoder│
             └─────┬────┘    └─────┬────┘    └─────┬────┘
                   │               │               │
                   ▼               ▼               ▼
             ┌──────────────────────────────────────────┐
             │              Node 树 (IR)                 │
             │  (含 comments / inlineComment 元数据)     │
             └─────────────┬────────────────────────────┘
                           │
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
      ┌──────────┐  ┌──────────┐  ┌──────────┐
      │YAMLParser │  │JSON Data │  │TOMLParser│
      │ serialize│  │ serialize│  │ serialize│
      └──────────┘  └──────────┘  └──────────┘
             │             │             │
             ▼             ▼             ▼
        YAML String    JSON Data    TOML String
```

---

## 模块说明

| 模块 | 路径 | 说明 |
|------|------|------|
| [DynamicCodable](Sources/DynamicCodable/README.md) | `Sources/DynamicCodable/` | 核心 `Node` 数据结构、类型转换、Codable 协议实现 |
| [JSON](Sources/JSON/README.md) | `Sources/JSON/` | JSON 格式的薄桥接层，复用系统 JSONEncoder/Decoder |
| [YAML](Sources/YAML/README.md) | `Sources/YAML/` | 完整的 YAML 解析、序列化、Codable 编解码 |
| [TOML](Sources/TOML/README.md) | `Sources/TOML/` | 完整的 TOML v1.0 解析、序列化、Codable 编解码 |

---

## 依赖及其协议

| 依赖 | 版本 | 用途 | 开源协议 |
|------|------|------|---------|
| [swift-collections](https://github.com/apple/swift-collections) | 1.5.0+ | 提供 `OrderedDictionary` 用于 `Node.Object` 保持键插入顺序 | [Apache 2.0](https://github.com/apple/swift-collections/blob/main/LICENSE.txt) |

所有依赖均为 Apple 官方维护的开源库，与 DynamicCodable 一样可自由使用、修改和分发。

---

## 许可证

DynamicCodable 使用 **MIT 许可证**。详见 [LICENSE](LICENSE) 文件。

```
MIT License

Copyright (c) 2026 nuwa-agent

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 参与贡献

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交修改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

### 开发指引

- 运行测试：`swift test`
- 构建所有模块：`swift build`
- 构建特定模块：`swift build --target YAML`
- Swift 版本要求：6.2+
