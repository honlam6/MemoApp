# MemoApp — iPhone + Apple Watch 备忘录

一个 SwiftUI 双端备忘录应用，支持 Markdown 编辑、LaTeX 数学公式渲染、iPhone ↔ Apple Watch 实时同步。

## 功能

- **Markdown 编辑** — 标题、段落、列表、表格、代码块、分割线
- **LaTeX 数学公式** — 块级公式 `$$...$$` / `\[...\]` 与行内公式 `$...$`
- **Apple Watch 阅读** — 手表端只读浏览，表冠滚动，手指横拖超宽公式
- **实时同步** — 通过 WCSession 将 iPhone 笔记同步到 Apple Watch
- **字号调节** — Watch 端支持多档字体大小切换

## 技术栈

- SwiftUI (iOS 17.0+ / watchOS 10.0+)
- [SwiftUIMath](https://github.com/gonzalezreal/swiftui-math) — 原生 LaTeX 渲染
- WCSession — iPhone ↔ Watch 通信
- XcodeGen (`project.yml`) — 项目配置生成

## 项目结构

```
MemoApp/
├── iPhone/                    # iOS App
│   ├── App/                   # App 入口 + 设置
│   └── Views/                 # MarkdownPreview, NoteEditor, NoteList, FileImport
├── Watch/                     # watchOS App
│   ├── App/                   # App 入口 + WatchNoteStore
│   └── Views/
│       └── Components/        # CompactTableView, MarkdownTextView, VelocityScrollView
├── WatchWidgets/              # watchOS Widget Extension
├── Shared/                    # 双端共享代码
│   ├── Models/                # Note 模型
│   ├── Storage/               # NoteStorage (UserDefaults + App Group)
│   ├── Sync/                  # WatchSyncManager (WCSession)
│   ├── Utils/                 # MarkdownParser, MarkdownInlineParser, HorizontalDragBounds
│   └── Views/                 # LaTeXRenderViews (LaTeXBlockView, InlineMathTextView 等)
├── Tests/                     # 单元测试
├── project.yml                # XcodeGen 配置
└── README.md
```

## 构建

```bash
# 安装 XcodeGen（如未安装）
brew install xcodegen

# 生成 .xcodeproj
cd MemoApp
xcodegen generate
open MemoApp.xcodeproj
```

在 Xcode 中选择 `MemoiPhone` scheme，连接 Apple Watch 后运行即可。

## 已知问题

- Watch 端触摸屏幕后 Digital Crown 滚动可能失效（焦点竞争问题，修复中）

## License

MIT