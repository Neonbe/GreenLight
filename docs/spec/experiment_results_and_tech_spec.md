# GreenLight（原 Gatekeeper Companion）：实验结果 & 修订版技术方案

## 一、实验结果记录

> 实验环境：macOS Tahoe (26.x)，Apple Silicon (M 系列)  
> 实验时间：2026-03-02 00:08 ~ 00:27

### 实验 A：`log stream` 日志监听

**结论：✅ 完全可行，完整路径可提取**

| 项目 | 结果 | 详情 |
|------|------|------|
| CoreServicesUIAgent 有日志 | ✅ | 88 行 |
| syspolicyd 有日志 | ✅ | 635 行 |
| 广泛关键词命中 | ✅ | `quarantine` / `GK` / `xprotect` |
| **日志包含 app 完整路径** | ✅ | `file:///Applications/Antigravity%20Tools.app/` |
| **日志包含 bundle_id** | ✅ | `com.lbjlaq.antigravity-tools` |
| **弹窗行为确认** | ✅ | `Prompt shown (1, 0), waiting for response` |
| 弹窗类型 | 弹窗模式 | "is damaged and can't be opened" |

**路径提取关键日志行**：
```
syspolicyd: GK Xprotect results: ...,file:///Applications/Antigravity%20Tools.app/
syspolicyd: GK evaluateScanResult: ...(bundle_id: com.lbjlaq.antigravity-tools)
CoreServicesUIAgent: LAUNCH: ... com.lbjlaq.antigravity-tools (quarantined)
syspolicyd: Prompt shown (1, 0), waiting for response: ...(bundle_id: com.lbjlaq.antigravity-tools)
```

> [!WARNING]
> 部分字段被 Apple 隐私策略标记为 `<private>`，但 XProtect results 中的 `file://` URL **未被遮蔽**。这可能是 Apple 的疏忽，不能保证在未来版本中持续可用。需要将此作为主通道但保留降级方案。

### 实验 B：FSEvents 文件系统监控

**结论：✅ 即时检测，需去重**

| 项目 | 结果 |
|------|------|
| FSEvents 检测 .app 创建 | ✅ 即时 |
| 读取 quarantine 属性 | ✅ 完整值 |
| 注意事项 | ⚠️ 同一 app 触发 7 次（Bundle 多文件），需去重 |

### 实验 C：`xattr -rd` 权限测试

**结论：✅ 无需 sudo，彻底简化方案**

| 目录 | 无 sudo 移除 | 退出码 |
|------|-------------|--------|
| `~/Downloads` | ✅ 成功 | 0 |
| `/Applications` | ✅ 成功 | 0 |

> [!IMPORTANT]
> **这是本次实验最重要的发现。** 不需要 sudo → 不需要 Terminal 注入 → 不需要 Privileged Helper Tool → 不需要 Automation 权限。App 内直接通过 `Process` 执行 `xattr -rd com.apple.quarantine <path>` 即可。

---

## 二、修订版技术方案

### 设计哲学

基于实验结果，修订后的方案遵循三个原则：

1. **极简权限**：实验证明核心功能无需 sudo / Accessibility / Automation，权限要求降至最低
2. **双通道冗余**：log stream（精准触发）+ FSEvents（稳定兜底），互为降级备份
3. **与 Sentinel 正交竞争**：不做 Sentinel 已有的功能（拖拽/右键），聚焦 Sentinel 没做的（自动检测 + 主动推送 + 安全仪表盘）

### 产品定位修订

```
原始定位：伴随系统弹窗的可视化确认工具
        ↓
修订定位：GreenLight —— 后台智能守卫 + 红绿灯安全仪表盘
```

| 维度 | 原始方案 | 修订方案 |
|------|---------|---------|
| **交互模式** | 伴随弹窗的浮动卡片 | Menu Bar 常驻 + 原生通知 |
| **检测方式** | log stream 单通道 | log stream + FSEvents 双通道 |
| **修复方式** | Terminal 注入 sudo xattr | App 内直接 `Process` 执行 xattr（无需 sudo） |
| **权限需求** | Accessibility + Automation | ~~仅 Full Disk Access（可选）~~ 见下方分析 |
| **竞争策略** | 与 Sentinel 同质化 | 与 Sentinel 正交互补 |

### 权限需求分析

| 权限 | 是否必需 | 用途 | 替代方案 |
|------|---------|------|---------|
| **Full Disk Access** | 🟡 可选 | 读取 `/Applications` 以外目录的 xattr | 大部分目录不需要 |
| **通知** | ✅ 必需 | 推送"检测到被隔离 app"通知 | 无 |
| ~~Accessibility~~ | ❌ 不需要 | ~~定位系统弹窗~~ | 已移除弹窗伴随设计 |
| ~~Automation~~ | ❌ 不需要 | ~~控制 Terminal~~ | 已改为 App 内直接执行 |

### 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                   🚦 GreenLight                         │
│                   (Menu Bar App)                        │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │             Detection Layer (双通道)             │    │
│  │                                                  │    │
│  │  ┌──────────────────┐  ┌──────────────────────┐ │    │
│  │  │  Channel A:      │  │  Channel B:          │ │    │
│  │  │  LogStreamMonitor│  │  FSEventsWatcher     │ │    │
│  │  │                  │  │                      │ │    │
│  │  │  监听 syspolicyd │  │  监听 ~/Downloads    │ │    │
│  │  │  "GK Xprotect"  │  │  /Applications 等    │ │    │
│  │  │  → 提取 file://  │  │  → 检查 xattr       │ │    │
│  │  │     URL 路径     │  │     quarantine       │ │    │
│  │  └────────┬─────────┘  └──────────┬───────────┘ │    │
│  │           │                       │              │    │
│  │           └───────────┬───────────┘              │    │
│  │                       ▼                          │    │
│  │            ┌─────────────────────┐               │    │
│  │            │  EventDeduplicator  │               │    │
│  │            │  (3s 窗口合并去重)   │               │    │
│  │            └──────────┬──────────┘               │    │
│  └───────────────────────┼──────────────────────────┘    │
│                          ▼                               │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Notification Layer                  │    │
│  │                                                  │    │
│  │  UserNotifications / Menu Bar Popover:           │    │
│  │  "macOS 拦截了 Antigravity Tools"                │    │
│  │  [❌ 忽略]  [🔓 修复]  [🛠 修复并打开]            │    │
│  └──────────────────────┬──────────────────────────┘    │
│                          ▼                               │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Action Layer                        │    │
│  │                                                  │    │
│  │  ┌─────────────────┐  ┌──────────────────────┐  │    │
│  │  │ QuarantineRemover│ │ CodeSignHelper       │  │    │
│  │  │ Process("xattr") │ │ Process("codesign")  │  │    │
│  │  │ 无需 sudo ✅     │ │ ad-hoc self-sign     │  │    │
│  │  └─────────────────┘  └──────────────────────┘  │    │
│  └──────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │       🚦 Traffic Light Dashboard (V2)            │    │
│  │                                                  │    │
│  │  🟢 绿灯 (已放行)：已修复的 app + 放行次数       │    │
│  │  🔴 红灯 (被拦截)：当前被隔离的 app              │    │
│  │  🟡 黄灯 (等待中)：扫描中/待决策                 │    │
│  │  统计：累计亮绿灯 N 次                           │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 核心模块设计

#### 模块 1：LogStreamMonitor

```swift
// 核心逻辑伪代码
class LogStreamMonitor {
    // 使用 Process 启动 log stream
    // predicate: 'process == "syspolicyd"'
    // 实时解析输出，正则匹配:
    //   - "GK Xprotect results:.*file://(.+\.app/)"  → 提取路径
    //   - "GK evaluateScanResult:.*bundle_id: (.+)\)" → 提取 bundle_id
    //   - "Prompt shown"                              → 确认弹窗已出现
    
    func startMonitoring() { ... }
    func parseLogLine(_ line: String) -> GatekeeperEvent? { ... }
}
```

**优势**：精准触发，只在 Gatekeeper 真正拦截时触发  
**风险**：日志格式可能随 macOS 版本变化  
**缓解**：版本适配 + Channel B 降级

#### 模块 2：FSEventsWatcher

```swift
// 核心逻辑伪代码
class FSEventsWatcher {
    // 使用 DispatchSource.makeFileSystemObjectSource 或 FSEventStream
    // 监控: ~/Downloads, /Applications, ~/Desktop 等常见目录
    // 当检测到 .app 文件变化时:
    //   1. 检查 xattr -p com.apple.quarantine
    //   2. 如果有 quarantine 属性 → 触发通知
    
    func startWatching(directories: [URL]) { ... }
    func checkQuarantine(at path: URL) -> Bool { ... }
}
```

**优势**：不依赖日志格式，稳定性极高  
**局限**：只能检测"新文件出现"，不能检测"用户双击被拦截"的精确时刻  
**去重策略**：3 秒时间窗口内同一 `.app` 路径只触发一次

#### 模块 3：QuarantineRemover

```swift
// 核心逻辑 - 极度简单
class QuarantineRemover {
    func removeQuarantine(at appPath: URL) -> Result<Void, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-rd", "com.apple.quarantine", appPath.path]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? .success(()) : .failure(...)
    }
}
```

> 实验 C 已证明：无需 sudo，无需 AuthorizationExecuteWithPrivileges，直接执行即可。

### 数据流时序

```
用户双击未签名 app
        │
        ▼
   macOS Gatekeeper 拦截
        │
        ├──→ syspolicyd 写入日志 ←── Channel A (LogStreamMonitor) 捕获
        │    "GK Xprotect results: file:///...app/"
        │
        ├──→ 系统弹窗 "is damaged and can't be opened"
        │
        ▼
   EventDeduplicator 合并去重
        │
        ▼
   UserNotifications 推送通知
   "🚨 检测到被隔离应用: Antigravity Tools"
   [一键修复]  [查看详情]  [忽略]
        │
        ▼ (用户点击"一键修复")
        │
   QuarantineRemover.removeQuarantine()
   → Process("xattr -rd com.apple.quarantine /path/to/app")
   → 退出码 0，成功
        │
        ▼
   通知: "✅ 已修复，现在可以正常打开 Antigravity Tools"
```

### MVP 范围定义

#### V1.0 (MVP) — 核心差异化

- [ ] Menu Bar 常驻（SwiftUI MenuBarExtra）
- [ ] LogStreamMonitor 日志监听
- [ ] FSEventsWatcher 文件监控
- [ ] EventDeduplicator 去重
- [ ] UserNotifications 通知推送
- [ ] QuarantineRemover 一键修复（无 sudo）
- [ ] 基础设置页（监控目录配置、开机启动）
- [ ] Onboarding 引导

#### V2.0 — 安全仪表盘

- [ ] Security Dashboard 全盘扫描
- [ ] 签名状态可视化
- [ ] 历史事件 Timeline
- [ ] 信任白名单管理
- [ ] CodeSignHelper 自签名

#### V3.0 — 生态扩展

- [ ] FinderSync 右键扩展（如果需要与 Sentinel 功能对齐）
- [ ] Homebrew 分发
- [ ] 自动更新器

### 与 Sentinel 的差异化矩阵

| 功能 | Sentinel | GreenLight | 说明 |
|------|----------|-----------|------|
| 拖拽解除隔离 | ✅ | ❌ (V1) / 🟡 (V3) | 不是我们的核心价值 |
| Finder 右键 | ✅ | ❌ (V1) / 🟡 (V3) | 同上 |
| 自签名 | ✅ | 🟡 (V2) | 次要功能 |
| **自动检测拦截** | ❌ | ✅ | **核心差异化** |
| **主动通知** | ❌ | ✅ | **核心差异化** |
| **三按钮修复（从通知）** | ❌ | ✅ | **核心差异化** |
| **红绿灯安全仪表盘** | ❌ | ✅ (V2) | 差异化 |
| **更新后重新放行** | ❌ | ✅ | 持续保护价值 |
| 后台常驻 | ❌ | ✅ | 差异化 |
| 商业化许可 | ❌ (Commons Clause) | ✅ | 商业空间 |

### 技术风险与缓解

| 风险 | 严重性 | 缓解措施 |
|------|--------|---------|
| Apple 未来遮蔽 XProtect results 中的路径 | 高 | FSEvents 作为降级通道；定期回归测试 |
| log stream 输出格式变化 | 中 | 正则表达式版本化；单元测试覆盖多种格式 |
| FSEvents 误触发（非 quarantine 的文件事件） | 低 | 先检查 xattr 再触发通知 |
| macOS 未来版本移除弹窗机制 | 中 | 核心功能不依赖弹窗存在，FSEvents 通道独立工作 |

### 开发语言与框架

- **Swift 5.9+ / SwiftUI** — Menu Bar App + Settings 页
- **Process (Foundation)** — 执行 `log stream`、`xattr`、`codesign`
- **FSEvents / DispatchSource** — 文件系统监控
- **UserNotifications** — 原生通知推送
- **无沙盒分发**（GitHub + Homebrew）— 避免 App Sandbox 对 `log stream` 和 `xattr` 的限制
