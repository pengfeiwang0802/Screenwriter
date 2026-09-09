# Screenwriter（编剧助手）能力与接口文档

> **这份文档是给「外部 AI 助手」（如王二助手）读的说明书。**
> 任何 AI 应用在第一次接触 Screenwriter 时，应先读本文件，即可明白如何与它交互——
> **不需要改 Screenwriter 的代码，也不需要王二助手写死任何按钮。**

---

## 0. 一句话定位

Screenwriter 是一个**专注于剧本内容创作**的 macOS 原生应用（Swift + AppKit + WKWebView）。
它只做一件事：帮人写剧本（.sws 单剧本）和组织剧本项目（.swsproj 项目）。

它**不知道也不关心**王二助手是谁。反过来，王二助手也不需要知道 Screenwriter 内部怎么实现——
只需要知道怎么**唤起它、给它文件、读它的结果**。这就是本文件存在的意义。

---

## 1. 两个 AI 的分工（架构原则，很重要）

| | 王二助手（通用 Agent） | Screenwriter（编剧助手） |
|---|---|---|
| **定位** | 用户的超级助手，**能力超集**，"掌控一切" | 只专注剧本创作这一个功能领域 |
| **认知** | 不需要知道 Screenwriter 存在 | 不需要知道王二助手存在 |
| **如何协作** | 通过读本文件**学会**如何调用 Screenwriter | 通过稳定的接口（URL scheme / 文件）被唤起 |
| **负责** | 帮用户完成"不会用 app"的操作：配置、增删场次、答疑、甚至下场帮忙操作 | 专注剧本内容本身 |

**关键推论：**
- 用户用 app 遇到困难（作家哪会配 API key / 增删场次 / 不会用工具）→ **王二助手来帮**，通过本文件学会操作 Screenwriter
- 用户要专注写剧本 → **Screenwriter 内部 AI** 只处理内容，不掺和别的

---

## 2. 如何唤起 Screenwriter（接口总览）

### 2.1 应用信息

| 项 | 值 |
|---|---|
| **应用名** | 编剧助手（Screenwriter） |
| **Bundle ID** | `com.pengfei.screenwriter` |
| **安装路径** | `/Applications/Screenwriter.app` |
| **版本** | v0.1.0（见 Info.plist `CFBundleShortVersionString`） |
| **最低系统** | macOS 14.0 |

### 2.2 三种唤起方式

| 方式 | 用途 | 命令 |
|---|---|---|
| **① 直接启动** | 打开 app（空项目或上次会话） | `open -a Screenwriter` 或 `open /Applications/Screenwriter.app` |
| **② 双击文件** | 打开一个 `.swsproj` / `.sws` 文件 | 系统 `open <file>`（已注册文件关联）|
| **③ URL scheme** | 带路径唤起（最灵活，AI 首选） | `open "screenwriter://open?path=<绝对路径>"` |

**AI 首选方式 ③**：一个 `open` 命令就能唤起并打开指定文件，无需知道 app 是否已运行
（已运行则聚焦，未运行则启动后打开）。

---

## 3. 文件格式（数据契约）

Screenwriter 读写两种文件。外部 AI 如果要**生成/修改**剧本，必须遵守以下格式。

### 3.1 `.sws` —— 单个剧本文件（纯文本）

- **本质**：UTF-8 纯文本，人类可读可手写
- **结构**：由 SWSFormatter 序列化/反序列化（`Sources/SWS/SWSFormatter.swift`）
- **内容模型**：`SWSDocument`（`Sources/SWS/SWSModel.swift`）——场景(scenes)、块(blocks，对白/动作/场景标题等)
- **⚠️ 已知 API 细节**：`SWSDialogueBlock` 当前用**单数 `line:`** 参数（不是数组 `lines:`）
  - 若外部要生成 .sws，**务必用 `sws-tool serialize` 验证**一次，确保格式被正确解析
  - 参考命令见下方 §5「工具」

### 3.2 `.swsproj` —— 剧本项目文件（JSON）

- **本质**：JSON（Info.plist 中 `UTTypeConformsTo: public.json`）
- **结构**：`SWSProject`（`Sources/SWS/SWSProject.swift`）
  - `swsproj`：版本标记
  - `meta`：`SWSProjectMeta`（title / author / createdAt / updatedAt）
  - `characters`：`[SWSProjectCharacter]`（name / color / tagline / avatar）
  - `scenes`：`[SWSProjectScene]`
  - `scripts` / `tree`：剧本引用与大纲树
  - `outline`：整体大纲文本
- **用途**：组织多个 .sws 剧本 + 角色 + 大纲的"主控文件"

---

## 4. 接口细节（供 AI 精确调用）

### 4.1 URL scheme 参数

```
screenwriter://open?path=<URL编码的绝对文件路径>
```

- `path`：必填，要打开的 `.swsproj` 或 `.sws` 文件的**绝对路径**
- 例：`open "screenwriter://open?path=/Users/me/Documents/我的剧本.swsproj"`
- 文件不存在时 app 会忽略并打印日志，不崩溃

### 4.2 文件分发规则（app 收到文件后）

| 扩展名 | 走哪个逻辑 | 效果 |
|---|---|---|
| `.swsproj` | `projectManager.loadProject` | 打开**项目**（含角色/大纲/多剧本）|
| `.sws` | `loadSWSFile` | 打开**单个剧本**文件 |
| 其他 | 忽略 | 打印日志 |

### 4.3 时序注意（AI 无需关心，但了解有助）

- 若 app 未运行、靠双击文件启动：文件会在 HTML 加载完成后自动打开（有 pending 缓存机制）
- 若 app 已运行：立即打开

---

## 5. 工具链（AI 可用的验证/操作手段）

Screenwriter 自带一个命令行工具 `sws-tool`（依赖 SWS 库），可读/验证 `.sws` 文件：

```bash
# 在 Screenwriter 仓库目录下编译后：
swift run sws-tool <子命令> <文件.sws>
```

| 子命令 | 作用 |
|---|---|
| `roundtrip` | 读入 → 序列化 → 反序列化 → 再序列化，验证格式稳定 |
| `serialize` | 读入 .sws → 输出序列化文本（**生成文件后用它验证**）|
| `info` | 读入 .sws → 输出统计信息 |
| `validate` | 读入 .sws → 检查格式合法性 |

> **给 AI 的实用建议**：如果你要**程序化生成**一个 .sws 文件，写完后跑
> `sws-tool serialize`（或 `validate`）确认能被正确解析，再交给 Screenwriter 打开。

---

## 6. 内部架构速览（AI 若要读源码）

```
Sources/
├── Screenwriter/            # App 壳 + UI + 宿主
│   ├── AppDelegate.swift    #   URL scheme / 文件打开入口（application(_:open:)）
│   ├── ScriptwritingPlugin.swift  # 核心控制器：窗口、loadSWSFile、openDocument、bridge
│   ├── SWSProjectManager.swift    # 项目(.swsproj)加载/保存
│   ├── ScriptwritingEditHandler.swift  # 编辑动作处理
│   ├── FormatTemplate.swift / TemplateWindows.swift  # 格式模板
│   ├── Resources/scriptwriting.html  # 编辑器前端（WKWebView）
│   └── Info.plist           #   文件类型 + URL scheme 注册
├── SWS/                     # 纯逻辑库（无 UI，可被外部复用）
│   ├── SWSModel.swift       #   SWSDocument / SWSDialogueBlock 等数据模型
│   ├── SWSFormatter.swift   #   .sws 文本 ⇄ SWSDocument 序列化
│   ├── SWSProject.swift     #   SWSProject(.swsproj) 数据模型
│   ├── SWSRenderer.swift    #   渲染
│   ├── SWSEditorState.swift #   编辑器状态
│   ├── SWSConfig.swift      #   显示风格 / 导入规则（DisplayStyle / ImportProfile）
│   └── SWSImportProfile.swift
Tools/
└── sws-tool/                # 命令行工具（见 §5）
scripts/
└── package_release.sh       # 打包成 /Applications/Screenwriter.app
```

### 关键代码入口（AI 若要改/查）

| 想做什么 | 看这里 |
|---|---|
| 处理"被外部唤起" | `AppDelegate.application(_:open:)` + `handleScreenwriterURL` |
| 打开 .sws/.swsproj | `ScriptwritingPlugin.openDocument(url:)` → `openDocumentResolved` |
| 加载单个 .sws | `ScriptwritingPlugin.loadSWSFile(url:)` |
| 加载项目 .swsproj | `SWSProjectManager.loadProject(from:)` |
| 项目数据结构 | `SWSProject`（Sources/SWS/SWSProject.swift）|
| .sws 文本格式 | `SWSFormatter`（Sources/SWS/SWSFormatter.swift）|

---

## 7. 给外部 AI 的协作建议（怎么帮用户）

当用户（尤其是不懂技术的作家）在 Screenwriter 里遇到困难时，外部 AI 可以：

1. **先读本文件**，搞清 Screenwriter 能做什么、怎么调用
2. **用 URL scheme 唤起并打开文件**：`open "screenwriter://open?path=..."`
3. **帮用户操作**：
   - 不会配 API key / token → 外部 AI 代劳（Screenwriter 内部 AI 不负责这个）
   - 不会增删场次 / 不会用工具 → 外部 AI 通过接口或直接帮点
4. **需要程序化改剧本** → 生成/修改 `.swsproj`(JSON) 或 `.sws`(文本)，用 `sws-tool` 验证后交给 Screenwriter

> **原则重申**：外部 AI 是"用户的操作助手 + 能力超集"，Screenwriter 是"内容专注者"。
> 两者通过本文件定义的稳定接口协作，互不硬编码、互不依赖内部实现。

---

## 8. 维护约定（重要！）

> ⚠️ **每次迭代 Screenwriter，必须同步更新本文件。** 这是硬性约定。

任何改动若涉及以下内容，**必须**在本文件对应章节同步更新：

| 改动类别 | 要更新的章节 |
|---|---|
| 新增/修改 URL scheme 或参数 | §2.2、§4.1 |
| 新增/修改文件类型或扩展名 | §3、§4.2 |
| 新增/修改 .sws / .swsproj 数据结构 | §3 |
| 修改 SWSFormatter 序列化规则 | §3.1 |
| 新增/修改 sws-tool 子命令 | §5 |
| 架构调整（文件搬移/新增模块）| §6 |
| 版本号 / Bundle ID 变化 | §2.1 |

**不更新 = 文档失联 = 外部 AI 学会的是过期接口 = 协作断裂。**
所以：改代码 → 改本文件 → 一起提交。
