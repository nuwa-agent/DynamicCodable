# Example 示例应用

> SwiftCoderTUI 库的完整可运行示例，展示了如何构建一个 AI 编码助手的终端界面。

**3 个源文件** | **依赖**: SwiftCoderTUI | **启动**: `swift run Example`

---

## 功能演示

运行该示例可以看到以下完整流程：

1. **终端启动** - 设置原始模式、安装 SIGWINCH 窗口变化信号处理器
2. **欢迎界面** - 显示欢迎消息和快捷键提示
3. **输入处理** - Readline 风格编辑（Ctrl+A/E/U/K/W）、多行输入（Shift+Enter/Alt+Enter）
4. **命令系统** - 完整的斜杠命令支持：

   | 命令 | 说明 |
   |------|------|
   | `/model` | 切换 AI 模型 (apex-ultra/apex-swift/nova-coder/prism-flash) |
   | `/mode` | 切换思考模式 (off/minimal/low/medium/high) |
   | `/caffeinate` | 防休眠管理 (on/off/busy/30m/1h/2h) |
   | `/clear` | 清空对话 |
   | `/help` | 显示快捷键帮助 |
   | `/demo` | 运行完整的交互式模拟会话 |
   | `/markdown` | 展示 Markdown 渲染效果 |
   | `/retry` | 重新提交上一次的 prompt |
   | `/status` | 显示当前会话状态 |
   | `/followup` | 排队一个后续 prompt |
   | `/quit` | 退出应用 |

5. **Shell 执行** - `!command` 执行并输出预览（注入 LLM），`!!command` 仅执行（不注入 LLM）
6. **流式输出** - 模拟 AI 流式响应（逐词输出 + 微调器动画）
7. **工具调用** - 模拟 `read_file`/`create_file`/`edit_file` 调用，含审批弹窗
8. **自动补全** - 斜杠命令 + 文件路径 + @提及三重补全
9. **Markdown 渲染** - 标题、代码块、表格、列表等
10. **Diff 显示** - 代码差异高亮着色
11. **状态栏** - 模型/模式徽章、微调器、待处理计数、活动文件

---

## 文件结构

```
Example/
└── Sources/
    ├── ExampleApp.swift    # 主入口 (@main)，应用配置，主事件循环
    ├── MockData.swift      # 模拟流式数据 (StreamEvent) 和 /demo 场景
    └── ModelCommand.swift  # /model 命令解析器和 ModelSlashCommand 补全提供器
```

---

## 文件详解

### [ExampleApp.swift](Sources/ExampleApp.swift)
- 716 行，应用的主入口文件
- 定义 `AppConfig`（4 个模型、5 个模式、10 个命令）
- **主事件循环**: `for await key in InputHandler.keystrokes()` 处理所有按键
- 处理 30+ 种按键的完整映射：方向键、Ctrl 组合、功能键、粘贴等
- 审批弹窗交互：数字键 1-4 选择、Enter 确认、Esc 取消
- 自动补全交互：Tab/Enter 接受、方向键导航、Esc 关闭
- Shell 执行集成：`!`/`!!` 前缀触发 `BashExecutor`
- 防休眠集成：`/caffeinate` 控制 `CaffeinateManager`

### [MockData.swift](Sources/MockData.swift)
- 356 行，提供模拟数据
- `StreamEvent` 枚举: `.thinking`, `.toolCall`, `.toolOutput`, `.word`, `.stats`, `.done`
- `MockData.stream(for:)` - 为指定 prompt 生成模拟流（包含随机思考和工具调用）
- `MockData.runDemo(renderer:)` - 完整 11 场场景的交互式演示（多轮对话 + 工具调用 + 审批 + 代码创建 + Diff + Markdown 展示）
- `MockData.runMarkdownDemo(renderer:)` - Markdown 渲染展示，涵盖所有块级和内联元素

### [ModelCommand.swift](Sources/ModelCommand.swift)
- 79 行，`/model` 命令解析器和自动补全
- `ModelCommandIntent` 定义: `.openMenu`, `.selectModel(index:)`, `.invalidModelName(String)`
- `ModelSlashCommand` 实现 `SlashCommand` 协议，提供模型名称的自动补全

---

## 如何运行

```bash
# 构建并运行
swift run Example

# 仅构建
swift build --target Example
```

## 键盘快捷键

| 按键 | 功能 |
|------|------|
| `Enter` | 提交输入 / 确认审批选择 / 只读模式下新建会话 |
| `Shift+Enter` | 在输入中换行 |
| `Alt+Enter` | 在输入中换行 |
| `Tab` | 打开命令面板 / 接受自动补全 |
| `Shift+Tab` | 切换会话 |
| `Ctrl+T` | 新建会话 |
| `Ctrl+W` | 编辑模式：删除前一个词 / 只读模式：关闭会话 |
| `Ctrl+P` | 切换下一个模型 |
| `Shift+Ctrl+P` | 切换上一个模型 |
| `Ctrl+A` | 移动到行首 |
| `Ctrl+E` | 移动到行尾 |
| `Ctrl+U` | 清除光标前的所有内容 |
| `Ctrl+K` | 清除光标后的所有内容 |
| `Ctrl+L` | 清空对话 |
| `Ctrl+C` | 退出应用 |
| `Ctrl+V` | 触发语音输入（需配置 Provider） |
| `Esc` | 取消流式生成 / 关闭自动补全 |
| `↑/↓` | 历史导航 / 自动补全选择导航 / 多行上下移动 |
| `←/→` | 光标左右移动 |

---

## 自定义示例

要修改示例以匹配你自己的应用场景：

1. **修改 `AppConfig`** - 更改应用名称、模型列表、模式、命令
2. **替换模拟数据** - 将 `MockData.stream(for:)` 替换为真实的 LLM API 调用
3. **添加新的命令处理器** - 在 `InputHandler` 循环中添加新的 `/command` 处理分支
4. **自定义自动补全** - 创建新的 `SlashCommand` 实现并注册到 `CombinedAutocompleteProvider`
