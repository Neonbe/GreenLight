# Gatekeeper Companion 可行性评审报告

## 【前置理解】现状基线

### macOS 安全机制现状（截至 macOS 15 Sequoia）

1. **Gatekeeper 持续收紧**：macOS Sequoia 已移除 Control-click → "Open" 的绕过方式，用户必须进入 `系统设置 > 隐私与安全性` 手动授权。`spctl --master-disable` 也已失效，Apple 的安全策略方向是**持续收紧而非放松**。
2. **quarantine 属性机制**：通过网络下载的文件被 macOS 自动打上 `com.apple.quarantine` 扩展属性，Gatekeeper 在首次打开时对该属性进行安全检查。`xattr -rd com.apple.quarantine` 仍然是社区公认的最常用解决方案。
3. **现有竞品**：GitHub 上已有 [macOS-GateKeeper-Helper](https://github.com/nicehash/macOS-GateKeeper-Helper) 等工具，提供检查 Gatekeeper 状态、移除隔离、自签名应用等功能。但这些工具普遍缺乏"事件监听 + 伴随式 UI"的自动化体验。

---

## 【评审步骤】发现清单

### 【✅发现1】：[高] macOS Sequoia 的安全策略演进方向与产品核心假设存在根本性冲突

- **评审发现**：文档的核心场景建立在"系统弹出 Gatekeeper 警告弹窗"这一触发机制之上。但 macOS Sequoia（15.x）已经将 Gatekeeper 的处理流程从弹窗模式逐步迁移到 `系统设置 > 隐私与安全性` 页面。在最新系统上，用户遇到的不是传统的"无法验证开发者"弹窗（仅有"取消"和"移到废纸篓"两个按钮），而是需要去系统设置中寻找"仍然打开"的按钮。这意味着：
  - **伴随式 UI（Side-by-side UI）的触发时机和锚定位置的前提假设可能已经失效**——如果 Apple 未来完全移除弹窗，改为仅在系统设置中处理，那么"贴靠在系统弹窗旁边"的设计就失去了存在基础。
  - Apple 每个大版本都在调整 Gatekeeper 的 UI 流程，产品的核心交互依赖于逆向工程 Apple 的私有 UI 行为，**极度脆弱**。
- **待确认问题**：在 macOS 15.x 上实测，Gatekeeper 拦截时是否仍然弹出 `CoreServicesUIAgent` 管理的窗口？还是已经完全改为系统设置跳转？不同场景（.app / .pkg / .dmg）的行为是否一致？
- **建议方案**：将核心交互从"伴随系统弹窗"调整为**独立的 Menu Bar 通知模式**——检测到拦截事件后，通过 macOS 原生通知（`UserNotifications`）或 Menu Bar 弹出面板告知用户，而非试图定位并贴靠系统弹窗。这样可以解耦对 Apple 私有 UI 的依赖。

### 【✅发现2】：[高] Accessibility API 权限获取与用户体验之间存在严重矛盾

- **评审发现**：使用 `AXUIElement` 获取 Gatekeeper 弹窗坐标需要**辅助功能权限**。这意味着：
  1. 用户首次安装时就需要授予一个"安全辅助工具"对整台电脑完全控制的权限——这在安全场景下极具讽刺意味，会严重降低用户信任。
  2. macOS 对 Accessibility 权限的获取越来越严格，用户需要手动前往系统设置解锁隐私面板并勾选应用，流程复杂。对于一个"降低操作摩擦"的工具来说，极重的前置授权流程会杀死大部分用户的安装意愿。
  3. 未来 Apple 可能进一步限制 Accessibility API 对系统级窗口（如 `CoreServicesUIAgent`）的访问权限。
- **待确认问题**：是否可以通过 `NSWorkspace` 的通知或 FSEvents 等更轻量级的 API 感知 Gatekeeper 事件，避免依赖 Accessibility API？
- **建议方案**：如采用发现1的建议方案（Menu Bar 通知模式），则可**完全移除对 Accessibility API 的依赖**，仅保留日志监听和 Automation 权限，大幅降低用户授权门槛。

### 【✅发现3】：[高] 通过 `log stream` 子进程实时监听日志的方案存在可靠性和性能风险

- **评审发现**：文档方案是通过 `Process` 启动 `log stream` 子进程来监听系统日志。此方案存在以下问题：
  1. **性能问题**：`log stream` 是一个持续运行的高输出子进程，即使使用了 `--predicate` 过滤，在繁忙系统上仍可能产生大量输出，与"极低内存占用"的目标相矛盾。
  2. **可靠性问题**：`log stream` 输出的日志格式不是 Apple 的公开稳定 API。日志消息的格式、字段名、甚至是否输出，都可能在系统更新后发生变化。使用正则表达式解析这些日志极其脆弱。
  3. **权限问题**：部分 `syspolicyd` 的日志可能需要 root 权限才能读取（Sequoia 对日志访问也在收紧），这意味着普通用户运行的 Menu Bar App 可能无法读取关键日志。
  4. **进程管理复杂性**：需要处理子进程崩溃、重启、管道缓冲区溢出等边界情况。
- **待确认问题**：在 macOS 15 上，不使用 `sudo` 的 `log stream` 能否成功捕获到 `CoreServicesUIAgent` 或 `syspolicyd` 的 Gatekeeper 拦截事件？日志中是否包含被拦截应用的完整路径？
- **建议方案**：
  - **方案A（推荐）**：使用 Apple 的 `OSLog` 框架的原生 Swift API（`OSLogStore`）替代 `log stream` 子进程，通过轮询方式定期检查最近的日志条目，而非持续流式监听。性能更优，接口更稳定。
  - **方案B**：使用 `FSEvents` 或 `DispatchSource.FileSystemEvent` 监听 `/Applications` 等关键目录的文件变化，结合 `xattr` 检查来发现新下载的被隔离应用。这种方式完全避免了日志解析的脆弱性。
  - **方案C**：使用 `NSWorkspace.didTerminateApplicationNotification` 结合 `launchctl` 等方式监测应用启动失败事件。

### 【✅发现4】：[高] NSAppleScript 终端自动化方案在沙盒环境下不可行，且与 App Store / Setapp 上架目标冲突

- **评审发现**：
  1. **App Sandbox 限制**：macOS App Store 和 Setapp 均要求应用必须启用 App Sandbox。沙盒应用默认**不能**发送 AppleEvent 到其他应用。虽然可以通过 `com.apple.security.scripting-targets` 或 `com.apple.security.temporary-exception.apple-events` 等 entitlement 来获取临时例外，但这类例外在 App Store 审核中几乎不可能通过，Setapp 也未必接受。
  2. **sudo 命令问题**：即使成功调用了 Terminal，`sudo xattr` 命令需要密码输入。文档声明"不代为输入密码"，所以用户仍然需要在 Terminal 中手动输入密码——这实质上只是将"打开终端 → 输入命令 → 输入密码"简化为"点按钮 → 输入密码"。**节省的步骤非常有限**，用户价值存疑。
  3. **安全审查风险**：一个应用自动向 Terminal 注入包含 `sudo` 的命令，这种行为模式与恶意软件的行为高度相似。在开源社区可能还好，但在任何审核平台上都会被重点审查。
- **待确认问题**：Setapp 对使用 AppleScript Automation 权限和调用 Terminal 的应用的审核政策是什么？是否有先例？
- **建议方案**：
  1. **放弃 Terminal 注入方案**，改用 `Process` 或 `NSTask` 在应用内部直接执行 `xattr -rd com.apple.quarantine` 命令。由于该命令对 `/Applications` 目录下的文件操作不一定需要 `sudo`（取决于文件所有者），且用户自己下载的文件通常位于 `~/Downloads`，权限足够。
  2. 对于确实需要 `sudo` 的情况，使用 `AuthorizationExecuteWithPrivileges`（已 deprecated 但仍可用）或 `SMJobBless` 安装 Privileged Helper Tool，通过 macOS 原生的授权弹窗获取权限。**这是 macOS 上进行特权操作的标准做法**，比调用 Terminal 更安全、更优雅。
  3. 或在沙盒外分发（仅 GitHub + Homebrew），放弃 Setapp 上架目标。

### 【✅发现5】：[中] 被拦截应用路径的精准捕获存在多个未验证假设

- **评审发现**：文档假设可以从 `CoreServicesUIAgent` 或 `syspolicyd` 的日志中"精准提取当前被拦截的 .app 文件绝对路径"。但：
  1. 日志中是否包含完整路径并非确定的——Apple 可能出于安全考虑只记录部分信息或哈希值。
  2. 用户可能同时触发多个 Gatekeeper 事件（如批量打开多个未签名 app），如何准确关联"哪个日志事件对应哪个弹窗"是一个非平凡问题。
  3. `.app` Bundle 路径可能包含特殊字符（空格、Unicode 字符），正则解析需要严格处理转义。
- **待确认问题**：需要在真实 macOS 15 环境中实际抓取日志，确认路径字段的存在性和格式稳定性。
- **建议方案**：如果采用发现3建议的"FSEvents + xattr 检查"方案，可以完全绕开日志解析的路径提取问题，因为 FSEvents 直接提供文件路径。

### 【✅发现6】：[中] 竞品已存在，差异化不足

- **评审发现**：GitHub 上已有 `macOS-GateKeeper-Helper` 等工具提供 Gatekeeper 管理功能。此外，macOS Sequoia 本身已提供了一个内建方案——`系统设置 > 隐私与安全性 > "仍然打开"`，虽然步骤多，但 Apple 有意将其作为正式流程。
  - 更关键的是，许多技术用户（也就是你的目标用户）已经将 `xattr -rd com.apple.quarantine` 设为 shell alias 或绑定了 Automator/Alfred 工作流，解决方案的边际价值递减。
  - 如果受众是"不会用终端的用户"，这些用户通常也不会下载未签名应用。痛点和目标受众之间存在悖论。
- **待确认问题**：核心差异化到底是什么？"自动检测 + 弹窗伴随"如果因技术限制无法实现，产品还剩什么独特价值？
- **建议方案**：转变思路，从"伴随系统弹窗"转向**全方位的 Gatekeeper 管理工具**：
  - 支持拖拽 .app 到 Menu Bar 图标一键清除 quarantine
  - 支持右键菜单 Finder Extension（`FinderSync`）集成
  - 提供已安装应用的签名状态扫描
  - 提供一键自签名功能（`codesign --sign -`）
  - 这样即使自动监听场景受限，工具仍然有丰富的使用价值

### 【✅发现7】：[中] Setapp 上架策略与产品定位存在矛盾

- **评审发现**：
  1. **Setapp 要求应用必须签名并经过 notarization**。一个帮助用户绕过 Gatekeeper 的工具，本身要通过 Gatekeeper 的审核——这存在合规层面的尴尬。Setapp 是否接受一个功能上等同于"帮用户关闭安全检查"的应用，需要与 Setapp 团队确认。
  2. **免费 + 开源 + Setapp 三者并不完全兼容**。开源意味着代码公开、可自行编译，Setapp 用户的付费动力会下降。Setapp 更青睐有持续付费价值的 app，而一个"一键清隔离"的工具使用频率可能很低。
  3. 文档说的"按活跃度计算的被动收入"——Setapp 的分成模型是基于用户使用时长加权分配的，一个 Menu Bar 后台运行的轻量工具，活跃时长极低，分成收入也会非常有限。
- **待确认问题**：Setapp 对此类安全辅助工具的接受度如何？是否有先例？
- **建议方案**：商业化路径应更多考虑作为**引流工具**的角色（如文档中期策略），而非直接靠 Setapp 赚钱。如果要上 Setapp，需要扩充功能集（如发现6建议），使其成为一个全面的"macOS 安全卫士"类工具，而非单一功能点。

### 【✅发现8】：[低] 文档中的技术术语与实际行为不匹配

- **评审发现**：
  1. 文档第三节标题"自动化脚本注入（Automated Scripting）"——"注入"一词在安全领域有强烈的负面含义（如 SQL injection、code injection）。用于描述一个安全工具的功能模块，措辞不当，容易引发误解和不必要的安全审查关注。
  2. "伴随式 UI 交互"中提到"严格要求不遮挡系统原生按钮，避免被判定为 UI 劫持"——这说明作者已意识到 UI 劫持风险，但使用 Accessibility API 定位系统弹窗并在旁边弹出自定义窗口这一行为本身就处于灰色地带，合规性取决于 Apple 的态度而非作者的意图。
- **待确认问题**：无。
- **建议方案**：将"脚本注入"改为"命令辅助生成（Command Generation）"或"终端辅助（Terminal Automation）"。整体文档在安全合规层面的措辞需要更加谨慎。

---

## 综合评估

| 维度 | 评级 | 说明 |
|------|------|------|
| **痛点真实性** | ⭐⭐⭐⭐ | 痛点确实存在，Sequoia 让流程变得更繁琐 |
| **技术可行性** | ⭐⭐ | 核心方案（日志监听 + 弹窗定位 + Terminal注入）每一环都有严重技术风险 |
| **合规安全性** | ⭐⭐ | 与 Apple 安全策略的演进方向存在对抗，长期维护成本高 |
| **商业化前景** | ⭐⭐⭐ | 作为引流工具有价值，但独立变现能力弱 |
| **差异化竞争力** | ⭐⭐ | 现有替代方案多，核心差异点（自动伴随弹窗）技术可行性存疑 |

## 建议的替代方案架构

如果要推进这个产品，建议以下调整后的技术方案：

```
┌────────────────────────────────────────────┐
│  Gatekeeper Companion (Menu Bar App)       │
│                                            │
│  ┌──────────┐  ┌────────────────────────┐  │
│  │ FSEvents │  │ Finder Extension       │  │
│  │ Watcher  │  │ (FinderSync)           │  │
│  │          │  │ 右键菜单集成            │  │
│  └────┬─────┘  └──────────┬─────────────┘  │
│       │                   │                │
│  ┌────▼───────────────────▼─────────────┐  │
│  │     Extension Attribute Scanner      │  │
│  │   - 检测 quarantine 属性              │  │
│  │   - 检测签名状态                      │  │
│  └────────────────┬─────────────────────┘  │
│                   │                        │
│  ┌────────────────▼─────────────────────┐  │
│  │     Action Engine                    │  │
│  │   - xattr 移除（无需 sudo）           │  │
│  │   - Privileged Helper（需 sudo 时）   │  │
│  │   - 自签名 (codesign)                │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  触发方式：                                 │
│  1. 拖拽 .app 到 Menu Bar 图标              │
│  2. Finder 右键菜单                        │
│  3. FSEvents 监听 + 通知提醒               │
│  4. 手动扫描指定目录                       │
└────────────────────────────────────────────┘
```

**核心改动**：
- 🔴 **移除** Accessibility API 依赖（不再试图定位系统弹窗）
- 🔴 **移除** NSAppleScript Terminal 注入方案
- 🟢 **新增** `FinderSync` 右键菜单集成（Apple 官方支持的 Finder 扩展机制）
- 🟢 **新增** 拖拽交互（最直观的用户操作路径）
- 🟡 **替换** `log stream` 为 FSEvents 文件系统监听 + xattr 检查
- 🟡 **替换** `sudo` Terminal 方案为 Privileged Helper Tool

这个替代方案在技术上更可靠，权限要求更低，用户体验更直观，且不与 Apple 的安全策略方向产生对抗。
