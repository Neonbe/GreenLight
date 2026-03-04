<div align="center">

# 🚦 GreenLight

**Never fight macOS Gatekeeper again.**

**再也不用和 macOS Gatekeeper 搏斗了。**

[**⬇️ Download Free**](https://github.com/Neonbe/GreenLight/releases/latest) · [**🌐 Website**](https://greenlight.notedock.app) · [**🐛 Report Bug**](https://github.com/Neonbe/GreenLight/issues)

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square)
![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square)
![Memory](https://img.shields.io/badge/memory-%3C30MB-purple?style=flat-square)

</div>

---

## The Problem | 问题

You download an app, double-click it, and macOS says it "can't be opened." So you open Terminal, Google the `xattr` command, carefully type a path, and hope for the best. Next week, the app updates — blocked again. Every. Single. Time.

你下载一个应用，双击打开，macOS 说「无法打开」。于是你打开终端，搜索 `xattr` 命令，小心翼翼地输入路径，祈祷它能生效。下周应用更新——又被拦了。每一次都是如此。

**GreenLight runs silently in your menu bar and handles all of this for you — automatically.**

**GreenLight 静默运行在菜单栏，自动帮你搞定这一切。**

---

## How It Works | 工作原理

| | EN | 中文 |
|:---:|---|---|
| 🔍 | **Auto-Detect** — Monitors your system in real-time. The instant Gatekeeper blocks an app, GreenLight knows. | **自动检测** — 实时监控系统。Gatekeeper 拦截应用的瞬间，GreenLight 就知道了。 |
| 🔔 | **Instant Alert** — A floating panel and native macOS notification pop up with the app name and action buttons. Under 5 seconds. | **即时提醒** — 浮动面板 + 系统通知弹出，显示应用名和操作按钮。5 秒内响应。 |
| 🛡️ | **One-Click Fix** — Hit "Fix & Open." Quarantine flag removed, app launched. No Terminal, no sudo, no Googling. | **一键修复** — 点击「修复并打开」。隔离标志移除，应用启动。无需终端，无需 sudo，无需搜索。 |

---

## Features | 功能

| | Feature | What it means for you |
|---|---|---|
| 🔍 | **Real-time Detection** | Blocked apps found in under 5 seconds — you never have to check manually |
| 🚦 | **Traffic Light Dashboard** | Red / Yellow / Green — see your system's security status at one glance |
| 📡 | **Menu Bar Guardian** | Always-on shield icon in your menu bar, click to open the full dashboard |
| 🔔 | **Floating Panel + Notification** | Two ways to get alerted — a floating panel at your screen corner + a standard macOS notification |
| 🔄 | **Smart Deduplication** | Installing one app triggers 7+ system events. GreenLight merges them into a single alert — no notification spam |
| 🔐 | **Privacy First** | Zero analytics, zero telemetry, zero network calls. Everything stays on your Mac |
| ⚡ | **Lightweight** | Under 30 MB memory, under 1% CPU when idle. You won't notice it's running |
| 🌍 | **Multilingual** | English & 中文 (more languages welcome via PR) |

---

## Installation | 安装

1. Download the `.dmg` from [**Releases**](https://github.com/Neonbe/GreenLight/releases/latest) | 从 [**Releases**](https://github.com/Neonbe/GreenLight/releases/latest) 下载 `.dmg`
2. Open it, drag GreenLight to `/Applications` | 打开后将 GreenLight 拖到「应用程序」
3. Launch — GreenLight now lives in your menu bar 🚦 | 启动后常驻菜单栏 🚦

**Requirements**: macOS 13 Ventura+ · Apple Silicon or Intel

---

## Architecture | 架构

This project uses a **partial open-source** model. The UI, notifications, utilities, and localizations are fully open. The detection engine core is proprietary.

本项目采用**部分开源**模式。UI、通知、工具和本地化完全开源，检测引擎核心闭源。

| Component | Status |
|---|:---:|
| UI & Views (10 SwiftUI files) | ✅ Open |
| Notification System | ✅ Open |
| Utilities (logging, persistence, animation, updater) | ✅ Open |
| Data Models & Localizations | ✅ Open |
| **Detection Engine (FSEvents, LogStream, Security validation)** | 🔒 Closed |
| **Security Actions (quarantine removal)** | 🔒 Closed |

> **Note**: The detection engine is not included in this repository. Clone + compile will not work. Please download the complete app from [Releases](https://github.com/Neonbe/GreenLight/releases/latest).
>
> **注意**：检测引擎不在此仓库中，克隆后无法编译。请从 [Releases](https://github.com/Neonbe/GreenLight/releases/latest) 下载完整版。

**Tech Stack**: `Swift 5.9+` · `SwiftUI` · `MenuBarExtra` · `FSEvents` · `Security.framework` · `UserNotifications` · `Sparkle 2`

---

## Contributing | 贡献

Contributions welcome in these areas | 以下方向欢迎贡献：

| | Area | 方向 |
|---|---|---|
| 🌐 | **Translations** — Add new languages | 添加新语言翻译 |
| 🎨 | **UI/UX** — Improvements and suggestions | 界面优化建议 |
| 📝 | **Documentation** — Better guides | 完善文档说明 |
| 🐛 | **Bug Reports** — File issues with repro steps | 附重现步骤的 Bug 报告 |

---

## FAQ

<details>
<summary><b>Does GreenLight need admin/sudo?</b> | <b>需要管理员权限吗？</b></summary>
<br>
No. GreenLight removes <code>com.apple.quarantine</code> without <code>sudo</code> for apps in standard locations (<code>~/Downloads</code>, <code>~/Desktop</code>, <code>/Applications</code>).
<br><br>
不需要。对于标准位置下的应用（下载、桌面、应用程序），无需 <code>sudo</code> 即可移除隔离属性。
</details>

<details>
<summary><b>Is it safe?</b> | <b>安全吗？</b></summary>
<br>
Yes. Open-source under MIT. Zero network calls, zero analytics, zero telemetry. Runs entirely on your machine — verify it yourself in the source code.
<br><br>
安全。MIT 开源许可。无网络请求、无数据采集、无遥测。完全本地运行——你可以亲自查看源码验证。
</details>

<details>
<summary><b>How is it different from Sentinel?</b> | <b>和 Sentinel 有什么区别？</b></summary>
<br>
Sentinel is a great drag-and-drop tool — but you have to know an app is blocked first. GreenLight <b>detects blocked apps automatically</b> and alerts you the moment it happens. You don't need to check anything.
<br><br>
Sentinel 是优秀的拖放工具——但前提是你得知道有应用被拦了。GreenLight <b>自动检测</b>被拦截的应用，在它发生的瞬间通知你。你什么都不用查。
</details>

<details>
<summary><b>Why is the detection engine closed-source?</b> | <b>为什么检测引擎闭源？</b></summary>
<br>
The detection engine represents significant R&D work in multi-pipeline orchestration, event correlation, and security validation. The UI, notifications, utilities, and localizations remain 100% open-source under MIT.
<br><br>
检测引擎凝聚了大量多管线编排、事件关联和安全校验的研发成果。UI、通知系统、工具类和本地化资源保持 MIT 许可下 100% 开源。
</details>

---

## License | 许可证

Open-source portions: [MIT License](LICENSE). Detection engine core: proprietary, distributed via [Releases](https://github.com/Neonbe/GreenLight/releases) only.

开源部分：[MIT 许可证](LICENSE)。检测引擎核心：闭源，仅通过 [Releases](https://github.com/Neonbe/GreenLight/releases) 分发。

---

<div align="center">

**Free forever. No tracking. No nonsense.**

**永久免费。无追踪。无废话。**

[**⬇️ Download GreenLight**](https://github.com/Neonbe/GreenLight/releases/latest)

</div>
