# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iPhone + Apple Watch SwiftUI memo app with Markdown editing, LaTeX math rendering (via SwiftUIMath), and iPhone ↔ Watch real-time sync via WCSession.

## Build & Test Commands

### Project Generation (XcodeGen)
```bash
xcodegen generate          # Generate .xcodeproj from project.yml
```
**Never hand-edit `.xcodeproj`** — `project.yml` is the source of truth.

### Build
```bash
# iPhone app
xcodebuild -project MemoApp.xcodeproj -scheme MemoiPhone -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO build

# Watch app (generic, no simulator needed)
xcodebuild -project MemoApp.xcodeproj -scheme MemoWatch -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath /private/tmp/MemoAppDerivedData build
```

### Tests (standalone executables, NOT XCTest)
Tests are compiled individually with `swiftc` and run as binaries:
```bash
# Markdown parser tests
swiftc -module-cache-path /private/tmp/swift-module-cache Shared/Utils/MarkdownParser.swift Tests/MarkdownParserTests.swift -o /tmp/MarkdownParserTests && /tmp/MarkdownParserTests

# Note data flow tests (title fallback, JSON round-trip)
swiftc -module-cache-path /private/tmp/swift-module-cache Shared/Models/Note.swift Tests/NoteDataFlowTests.swift -o /tmp/NoteDataFlowTests && /tmp/NoteDataFlowTests

# Horizontal drag bounds tests
swiftc -module-cache-path /private/tmp/swift-module-cache Shared/Utils/HorizontalDragBounds.swift Tests/HorizontalDragBoundsTests.swift -o /tmp/HorizontalDragBoundsTests && /tmp/HorizontalDragBoundsTests

# Shared import service tests
swiftc -module-cache-path /private/tmp/swift-module-cache Shared/Models/Note.swift Shared/Storage/NoteStorage.swift Shared/Import/NoteImportService.swift Tests/SharedNoteImportTests.swift -o /tmp/SharedNoteImportTests && /tmp/SharedNoteImportTests
```

Each test file has `@main` and `static func main()` with assertions — no XCTest framework involved.

## Architecture

### Targets (4 total)

| Target | Platform | Sources | Role |
|--------|----------|---------|------|
| **MemoiPhone** | iOS 17+ | `iPhone/` + `Shared/` | Main app |
| **MemoShareExtension** | iOS | `ShareExtension/` + partial `Shared/` | Share sheet import |
| **MemoWatch** | watchOS 10+ | `Watch/` + `Shared/` | Read-only watch app |
| **MemoWatchWidgets** | watchOS | `WatchWidgets/` + partial `Shared/` | AccessoryCircular complication |

MemoiPhone embeds MemoWatch and MemoShareExtension. MemoWatch embeds MemoWatchWidgets.

### Data Flow

```
iPhone: FileImportView/ShareExtension → NoteImportService → NoteStore → NoteStorage (UserDefaults + App Group)
                                                                        ↓
Sync:   WatchSyncManager (WCSession.transferUserInfo / sendMessage, hash-deduped)
                                                                        ↓
Watch:  WatchNoteStore ← WatchSyncManager.onNotesReceived → NoteStorage → NoteReaderView (read-only)
Widget: MemoWatchWidgets reads NoteStorage.loadNotes().count
```

All targets share App Group `group.com.memo.shared` via `UserDefaults(suiteName:)`.

### Code Patterns

- **Enum namespaces**: `NoteStorage`, `MarkdownParser`, `MarkdownInlineParser`, `NoteImportService`, `HorizontalDragBounds`, `LaTeXFormulaPreprocessor` are all `enum` types (no instances) with static methods.
- **ObservableObject stores**: `NoteStore` (iPhone, in `NoteListView.swift`) and `WatchNoteStore` (Watch, in `ContentView.swift`) — injected via `@EnvironmentObject`.
- **Singleton sync**: `WatchSyncManager.shared` manages WCSession lifecycle.
- **NSCache**: Both `MarkdownParser` and `MarkdownInlineParser` cache parsed results.

### Markdown Parser

Custom-built (not a library). Supports: headings, paragraphs, bullet/numbered lists, tables, code blocks, horizontal rules, `$$...$$` / `\[...\]` block math, `$...$` inline math. Table column splitting correctly ignores pipes inside math delimiters and backticks.

### Watch Performance

Deferred rendering: expensive blocks (math, tables) show placeholders until scrolled into view. `NoteReaderView` prefetches in batches of 8 at 120ms intervals. `VelocityScrollView` implements Digital Crown acceleration with exponential smoothing.

### Single External Dependency

[SwiftUIMath](https://github.com/gonzalezreal/swiftui-math) v0.1.0 — native SwiftUI LaTeX rendering. Declared in `project.yml` under `packages:`.

## Behavioral Guidelines

**Think before coding.** State assumptions. If uncertain, ask. Surface tradeoffs — don't pick silently.

**Simplicity first.** Minimum code that solves the problem. No speculative features, no abstractions for single-use code. If 200 lines could be 50, rewrite.

**Surgical changes.** Touch only what you must. Don't "improve" adjacent code. Match existing style. Every changed line should trace to the user's request.

**Goal-driven.** Define success criteria. For multi-step tasks, state a brief plan with verification steps. Loop until verified.
