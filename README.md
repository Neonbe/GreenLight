<div align="center">

# 🚦 GreenLight — Fix Apps Blocked by macOS Gatekeeper

**Never run `xattr -rd com.apple.quarantine` in Terminal again.**

**再也不用在终端里输入 `xattr -rd com.apple.quarantine` 了。**

[**⬇️ Download Free**](https://github.com/Neonbe/GreenLight/releases/latest) · [**🌐 Website**](https://greenlight.notedock.app) · [**🐛 Report Bug**](https://github.com/Neonbe/GreenLight/issues)

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square)
![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square)
![Memory](https://img.shields.io/badge/memory-%3C30MB-purple?style=flat-square)

</div>

---

## What is GreenLight? | GreenLight 是什么？

GreenLight is a free, open-source macOS utility that **automatically detects apps blocked by Gatekeeper** and removes the `com.apple.quarantine` extended attribute with one click. It runs silently in your menu bar, monitors your system in real-time, and sends you a native notification the moment an app is blocked — no Terminal, no `sudo`, no manual `xattr` commands needed.

GreenLight 是一款免费开源的 macOS 工具，**自动检测被 Gatekeeper 拦截的应用**，一键移除 `com.apple.quarantine` 扩展属性。它静默运行在菜单栏，实时监控系统，在应用被拦截的瞬间发送原生通知——无需终端，无需 `sudo`，无需手动输入 `xattr` 命令。

---

## The Problem | 问题

When you download apps outside the Mac App Store, macOS Gatekeeper adds a quarantine flag (`com.apple.quarantine`) that blocks them from opening. The standard fix? Open Terminal and run:

当你从 Mac App Store 以外下载应用时，macOS Gatekeeper 会添加隔离标志（`com.apple.quarantine`）阻止其打开。通常的解决办法？打开终端输入：

```bash
xattr -rd com.apple.quarantine /Applications/YourApp.app
```

Then the app updates next week — blocked again. **GreenLight automates this entire process.**

然后下周应用更新——又被拦了。**GreenLight 自动化了整个流程。**

---

## How It Works | 工作原理

| | EN | 中文 |
|:---:|---|---|
| 🔍 | **Auto-Detect** — Monitors your system in real-time. The instant Gatekeeper blocks an app, GreenLight knows. | **自动检测** — 实时监控系统。Gatekeeper 拦截应用的瞬间，GreenLight 就知道了。 |
| 🔔 | **Instant Alert** — A floating panel and native macOS notification pop up with the app name and action buttons. Under 5 seconds. | **即时提醒** — 浮动面板 + 系统通知弹出，显示应用名和操作按钮。5 秒内响应。 |
| 🛡️ | **One-Click Fix** — Hit "Fix & Open." Quarantine attribute removed, app launched. No Terminal, no sudo, no Googling. | **一键修复** — 点击「修复并打开」。隔离属性移除，应用启动。无需终端，无需 sudo，无需搜索。 |

---

## Features | 功能

| | Feature | What it means for you |
|---|---|---|
| 🔍 | **Real-time Gatekeeper Detection** | Blocked apps found in under 5 seconds — you never have to check manually |
| 🚦 | **Traffic Light Dashboard** | Red / Yellow / Green — see your Mac's security status at one glance |
| 📡 | **Menu Bar Guardian** | Always-on shield icon in your menu bar, click to open the full dashboard |
| 🔔 | **Floating Panel + Notification** | Two ways to get alerted — a floating panel at your screen corner + a standard macOS notification |
| 🔄 | **Smart Deduplication** | Installing one app triggers 7+ quarantine events. GreenLight merges them into a single alert — no notification spam |
| 🔐 | **Privacy First** | Zero analytics, zero telemetry, zero network calls. Everything stays on your Mac |
| ⚡ | **Lightweight** | Under 30 MB memory, under 1% CPU when idle. You won't notice it's running |
| 🌍 | **Multilingual** | English & 中文 (more languages welcome via PR) |

---

## GreenLight vs Alternatives | 对比

| Capability | Terminal (`xattr`) | Sentinel | **GreenLight** |
|---|:---:|:---:|:---:|
| Auto-detect blocked apps | ❌ | ❌ | ✅ |
| Real-time notifications | ❌ | ❌ | ✅ |
| One-click fix from notification | ❌ | ❌ | ✅ |
| Menu bar guardian | ❌ | ❌ | ✅ |
| First-run system scan | ❌ | ❌ | ✅ |
| No Terminal needed | ❌ | ✅ | ✅ |
| Drag & drop fix | ❌ | ✅ | ❌ |
| Free & open source | ✅ | ✅ | ✅ |

---

## Installation | 安装

1. Download the `.dmg` from [**Releases**](https://github.com/Neonbe/GreenLight/releases/latest) | 从 [**Releases**](https://github.com/Neonbe/GreenLight/releases/latest) 下载 `.dmg`
2. Open it, drag GreenLight to `/Applications` | 打开后将 GreenLight 拖到「应用程序」
3. Launch — GreenLight now lives in your menu bar 🚦 | 启动后常驻菜单栏 🚦

**Requirements**: macOS 13 Ventura+ · Apple Silicon (M1/M2/M3/M4) or Intel

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
<summary><b>What does GreenLight actually do?</b> | <b>GreenLight 具体做什么？</b></summary>
<br>
When you download an app from outside the Mac App Store, macOS adds a <code>com.apple.quarantine</code> extended attribute to the file. This attribute triggers Gatekeeper to block the app from opening. Normally you'd need to open Terminal and run <code>xattr -rd com.apple.quarantine /path/to/App.app</code> to remove it. GreenLight automates this — it detects blocked apps in real-time and removes the quarantine attribute with one click.
<br><br>
当你从 Mac App Store 以外下载应用时，macOS 会给文件添加 <code>com.apple.quarantine</code> 扩展属性，触发 Gatekeeper 阻止应用打开。通常你需要打开终端运行 <code>xattr -rd com.apple.quarantine /path/to/App.app</code> 来移除它。GreenLight 自动完成这一切——实时检测被拦截的应用，一键移除隔离属性。
</details>

<details>
<summary><b>Does GreenLight need admin/sudo?</b> | <b>需要管理员权限吗？</b></summary>
<br>
No. GreenLight removes <code>com.apple.quarantine</code> using the <code>xattr</code> API without <code>sudo</code> for apps in standard locations (<code>~/Downloads</code>, <code>~/Desktop</code>, <code>/Applications</code>).
<br><br>
不需要。对于标准位置下的应用（下载、桌面、应用程序），GreenLight 通过 <code>xattr</code> API 移除隔离属性，无需 <code>sudo</code>。
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
<a href="https://github.com/alienator88/Sentinel">Sentinel</a> is a great drag-and-drop quarantine removal tool — but you have to know an app is blocked first. GreenLight <b>detects blocked apps automatically</b> via real-time system monitoring and alerts you the moment it happens. You don't need to check anything manually.
<br><br>
<a href="https://github.com/alienator88/Sentinel">Sentinel</a> 是优秀的拖放式隔离移除工具——但前提是你得知道有应用被拦了。GreenLight 通过实时系统监控<b>自动检测</b>被拦截的应用，在它发生的瞬间通知你。你什么都不用手动查。
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
