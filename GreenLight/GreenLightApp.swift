import SwiftUI
@preconcurrency import Dispatch
import AppKit
import Sparkle

@main
struct GreenLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState.shared
    @StateObject private var updaterManager = UpdaterManager()
    
    
    private let logMonitor = LogStreamMonitor()
    private let fsWatcher = FSEventsWatcher()
    private let deduplicator = EventDeduplicator()
    private let remover = QuarantineRemover()
    private let enhanceManager = EnhancePromptManager()
    
    init() {
        setupPipeline()
    }
    
    var body: some Scene {
        // 1. 主窗口（Dock App 的核心入口）
        WindowGroup {
            MainWindowView(onWarmup: { [fsWatcher] in
                initialDetectionScan(fsWatcher: fsWatcher)
            })
                .environmentObject(appState)
                .environmentObject(updaterManager)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // 单窗口 App，禁止 Cmd+N
            
            // §r04: 用户操作打点器
            CommandGroup(after: .toolbar) {
                Button("⛱ User Timestamp") {
                    let ts = Int(Date().timeIntervalSince1970 * 1000)
                    GLLog.pipeline.notice("⏱ USER_MARK: \(ts) — user action NOW")
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
        
        // 2. Menu Bar 常驻（轻量入口 + 状态指示器）
        MenuBarExtra {
            PopoverView()
                .environmentObject(appState)
        } label: {
            MenuBarLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        
        // 3. 设置独立窗口
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(updaterManager)
        }
    }
    
    // MARK: - 检测管线搭建（§五）
    
    private func setupPipeline() {
        // Channel A → EventDeduplicator
        logMonitor.onDetection = { [deduplicator] event in
            deduplicator.receive(event)
        }
        
        // Channel B → EventDeduplicator
        fsWatcher.onDetection = { [deduplicator, logMonitor] event in
            // §r04: FSEvents 检出时关联最近 GK 事件
            let now = Date()
            let recentGK = logMonitor.recentGKEvents.filter { now.timeIntervalSince($0.timestamp) < 10 }
            if !recentGK.isEmpty {
                let scanCount = recentGK.filter { $0.category == .scan }.count
                let evalCount = recentGK.filter { $0.category == .evaluate }.count
                let promptCount = recentGK.filter { $0.category == .prompt }.count
                let otherCount = recentGK.filter { $0.category == .unrecognized }.count
                let oldestMs = Int(now.timeIntervalSince(recentGK.first!.timestamp) * 1000)
                GLLog.pipeline.notice("FS↔GK correlation: \(recentGK.count) GK events in last 10s (scan=\(scanCount) eval=\(evalCount) prompt=\(promptCount) other=\(otherCount)), oldest=\(oldestMs)ms ago")
            } else {
                GLLog.pipeline.notice("FS↔GK correlation: 0 GK events in last 10s")
            }
            deduplicator.receive(event)
        }
        
        // 被动观察：FSEvents 检测到 .app 变更（含文件消失）→ reconcile
        fsWatcher.onDirectoryChange = {
            Task { @MainActor in
                let appState = AppState.shared
                appState.reconcileDetectedApps()
                // 如果面板正在展示的 app 已消失，自动关闭
                if let panelEvent = appState.pendingPanelEvent,
                   !FileManager.default.fileExists(atPath: panelEvent.appPath.path) {
                    GLLog.panel.notice("Panel app gone (user trashed), auto-closing")
                    DetectionPanelController.shared.dismiss()
                }
            }
        }
        
        // EventDeduplicator → 浮动面板 + 状态更新
        deduplicator.onEvent = { event in
            Task { @MainActor in
                let latencyMs = Int(Date().timeIntervalSince(event.timestamp) * 1000)
                GLLog.pipeline.info("Pipeline received: \(event.appName), sources=\(event.sources.map { String(describing: $0) }), latency=\(latencyMs)ms")
                
                let appState = AppState.shared
                
                // §3.2 优化：已 blocked 的 App 跳过重复弹窗
                if let existing = appState.blockedApps.first(where: { $0.path == event.appPath.path }),
                   existing.status == .detected {
                    GLLog.pipeline.info("Already detected, skip panel: \(event.appName)")
                    // 但如果确认态面板还在等，仍然要替换
                    if DetectionPanelController.shared.isConfirming {
                        appState.isScanning = false
                        DetectionPanelController.shared.confirmWith(event: event)
                    }
                    return
                }
                
                appState.addDetectedApp(from: event)
                appState.isScanning = false
                
                // §r06: 如果确认态面板正在等 → 无缝替换
                if DetectionPanelController.shared.isConfirming {
                    GLLog.pipeline.info("Confirming → confirmed: \(event.appName)")
                    DetectionPanelController.shared.confirmWith(event: event)
                } else {
                    // 弹出检测浮动面板
                    GLLog.pipeline.info("Showing panel for: \(event.appName)")
                    DetectionPanelController.shared.show(event: event)
                }
                
                // 可选：如有系统通知权限，同时发送系统通知
                GLLog.pipeline.info("Sending system notification for: \(event.appName)")
                NotificationManager.shared.sendDetectionNotificationIfAuthorized(for: event)
            }
        }
        
        // === Level 0: 零权限通道，无条件启动 ===
        
        // Channel A: LogStream（不需要任何文件权限）
        logMonitor.startMonitoring()
        
        // Channel B (Level 0): 仅监控 /Applications（无 TCC）
        fsWatcher.startWatching(directories: FSEventsWatcher.level0Directories)
        
        // === Level 1: 用户曾授权则恢复监控（不触发 TCC 弹窗） ===
        
        if Persistence.level1Granted {
            // 用户曾通过引导面板授权，安全地恢复 Level 1 监控
            fsWatcher.addDirectories(FSEventsWatcher.level1Directories)
            GLLog.pipeline.notice("Level 1 restored at launch (previously granted)")
        }
        
        GLLog.pipeline.notice("Pipeline started: logStream=\(logMonitor.isRunning), fsEvents=\(fsWatcher.isRunning)")
        GLLog.pipeline.info("Monitoring directories: \(fsWatcher.currentMonitoredDirectories.map(\.path))")
        
        // 初始扫描：发现所有 unsigned app → 加入 detectedApps + 填充 L2 缓存
        if Persistence.hasCompletedOnboarding {
            // 非首次启动：立即扫描
            initialDetectionScan(fsWatcher: fsWatcher)
        }
        // 首次启动：由 OnboardingView onAppear 触发（见 onWarmup 回调）
        
        // onGKActivity → §r06 确认态流程 + 置信度记录 + fallback 兜底
        var lastProactiveScanTime: Date?
        let proactiveScanCooldown: TimeInterval = 5
        var fallbackScanTimer: DispatchWorkItem?
        var lastFallbackScanTime: Date?
        let fallbackCooldown: TimeInterval = 120
        var confirmTimeoutWork: DispatchWorkItem?
        
        logMonitor.onGKActivity = { [fsWatcher, deduplicator, enhanceManager] in
            // 记录 GK 活动到置信度窗口
            enhanceManager.recordGKActivity()
            
            // §r06: Menu Bar 黄灯 + Channel C 主动扫描
            let now = Date()
            if let lastScan = lastProactiveScanTime, now.timeIntervalSince(lastScan) < proactiveScanCooldown {
                let remaining = String(format: "%.1f", proactiveScanCooldown - now.timeIntervalSince(lastScan))
                GLLog.pipeline.debug("proactiveScan skipped: cooldown (\(remaining)s remaining)")
                Task { @MainActor in
                    AppState.shared.isScanning = true
                }
            } else {
                lastProactiveScanTime = now
                Task { @MainActor in
                    let appState = AppState.shared
                    appState.isScanning = true
                    // L3: 仅过滤已检出/已丢弃的 app（不含 clearedApps，更新后应重新检出）
                    let knownPaths = Set(appState.blockedApps.map { $0.path })
                    DispatchQueue.global(qos: .userInitiated).async {
                        let events = fsWatcher.proactiveScan(knownPaths: knownPaths)
                        guard !events.isEmpty else {
                            // 无发现 → 5s 后恢复绿灯
                            let greenLightWork = DispatchWorkItem {
                                Task { @MainActor in
                                    if AppState.shared.isScanning {
                                        AppState.shared.isScanning = false
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: greenLightWork)
                            return
                        }
                        
                        // 有发现 → 弹确认态面板
                        let sortedEvents = events.sorted { $0.appPath.path < $1.appPath.path }
                        let latencyMs = Int(Date().timeIntervalSince(events[0].timestamp) * 1000)
                        GLLog.pipeline.notice("proactiveScan: \(events.count) found, latency=\(latencyMs)ms, showing confirming panel")
                        
                        Task { @MainActor in
                            DetectionPanelController.shared.showConfirming(foundCount: events.count)
                        }
                        
                        // 5s 超时兜底：用首个未知 app 替换
                        confirmTimeoutWork?.cancel()
                        let timeoutWork = DispatchWorkItem {
                            Task { @MainActor in
                                guard DetectionPanelController.shared.isConfirming else { return }
                                let appState = AppState.shared
                                
                                // 过滤已知 app（竞态兜底：Channel A/B 可能已在 5s 内添加）
                                let newEvents = sortedEvents.filter { event in
                                    !appState.blockedApps.contains { $0.path == event.appPath.path }
                                }
                                
                                guard let first = newEvents.first else {
                                    // 全部已知 → 静默关闭确认态
                                    GLLog.pipeline.notice("proactiveScan timeout: all known, dismissing")
                                    appState.isScanning = false
                                    DetectionPanelController.shared.dismiss()
                                    return
                                }
                                
                                let appName = first.appPath.deletingPathExtension().lastPathComponent
                                let greenLightEvent = GreenLightEvent(
                                    appPath: first.appPath,
                                    appName: appName,
                                    bundleId: first.bundleId,
                                    sources: [.proactiveScan],
                                    timestamp: first.timestamp
                                )
                                GLLog.pipeline.notice("proactiveScan timeout fallback: \(appName)")
                                appState.addDetectedApp(from: greenLightEvent)
                                appState.isScanning = false
                                DetectionPanelController.shared.confirmWith(event: greenLightEvent)
                                NotificationManager.shared.sendDetectionNotificationIfAuthorized(for: greenLightEvent)
                            }
                        }
                        confirmTimeoutWork = timeoutWork
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutWork)
                    }
                }
            }
            
            // 原有 fallback scan（120 秒冷却，500ms 去抖）
            if let lastScan = lastFallbackScanTime {
                let elapsed = now.timeIntervalSince(lastScan)
                if elapsed < fallbackCooldown {
                    return
                }
            }
            fallbackScanTimer?.cancel()
            let work = DispatchWorkItem {
                GLLog.pipeline.info("Fallback scan triggered by GK activity")
                lastFallbackScanTime = Date()
                let events = fsWatcher.scanApps()
                for event in events {
                    deduplicator.receive(event)
                }
                // 扫描完成后 reconcile：文件消失的 🟡 → 🔴
                Task { @MainActor in
                    AppState.shared.reconcileDetectedApps()
                }
            }
            fallbackScanTimer = work
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5, execute: work)
            
            // 被动观察：GK 弹窗后用户可能点了 "Move to Trash"，延迟 3s reconcile
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let appState = AppState.shared
                appState.reconcileDetectedApps()
                // 如果当前面板显示的 app 已消失，自动关闭面板
                if let panelEvent = appState.pendingPanelEvent,
                   !FileManager.default.fileExists(atPath: panelEvent.appPath.path) {
                    GLLog.panel.notice("Panel app trashed by user, auto-closing")
                    DetectionPanelController.shared.dismiss()
                }
            }
        }
        
        // EnhancePromptManager 回调连接
        enhanceManager.onShowEnhancePanel = {
            Task { @MainActor in
                EnhancePanelController.shared.show(enhanceManager: enhanceManager)
            }
        }
        
        enhanceManager.onUpgradeToLevel1 = { [fsWatcher] grantedDirs in
            fsWatcher.addDirectories(grantedDirs)
            // 目标化扫描模式下，新增目录暂无 recentCandidates，由 FSEvents 实时检测后续事件
            GLLog.pipeline.notice("Level 1 upgraded: now monitoring \(grantedDirs.map(\.path))")
        }
    }
    
    // MARK: - 初始扫描
    
    /// 启动/Onboarding 初始扫描：发现所有 unsigned app → 加入 detectedApps + 填充 L2 缓存
    private func initialDetectionScan(fsWatcher: FSEventsWatcher) {
        Task { @MainActor in
            let appState = AppState.shared
            // L3: 仅过滤已检出/已丢弃（不含 clearedApps，更新后应重新检出）
            let knownPaths = Set(appState.blockedApps.map { $0.path })
            DispatchQueue.global(qos: .userInitiated).async {
                let events = fsWatcher.proactiveScan(knownPaths: knownPaths)
                guard !events.isEmpty else { return }
                Task { @MainActor in
                    let appState = AppState.shared
                    for event in events {
                        let appName = event.appPath.deletingPathExtension().lastPathComponent
                        appState.addDetectedApp(from: GreenLightEvent(
                            appPath: event.appPath,
                            appName: appName,
                            bundleId: event.bundleId,
                            sources: [.proactiveScan],
                            timestamp: event.timestamp
                        ))
                    }
                    GLLog.pipeline.notice("Initial scan: \(events.count) unsigned apps detected, total=\(appState.detectedApps.count)")
                }
            }
        }
    }
}

// MARK: - AppDelegate（处理 Dock 图标点击重开窗口）

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // MenuBarExtra + WindowGroup 并存时，SwiftUI 不一定会自动打开主窗口
        // 延迟一帧确保 WindowGroup 已创建，再显式激活
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 点击 Dock 图标 → 重新显示主窗口
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                return false
            }
        }
        return true
    }
}

/// Menu Bar 图标标签 — 盾牌 + 交通灯（NSImage template 渲染）
struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanRotation: Double = 0
    
    var body: some View {
        let detectedCount = appState.detectedApps.count
        
        if detectedCount > 0 {
            // 检测到目标：盾牌 + 数字角标
            Label {
                Text("\(detectedCount)")
            } icon: {
                Image(nsImage: MenuBarIconRenderer.shieldIcon())
            }
        } else if appState.isScanning {
            // 扫描中：盾牌 + 旋转弧线
            Image(nsImage: MenuBarIconRenderer.scanningIcon())
                .rotationEffect(.degrees(scanRotation))
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        scanRotation = 360
                    }
                }
                .onChange(of: appState.isScanning) { scanning in
                    if !scanning { scanRotation = 0 }
                }
        } else {
            // 常规态：盾牌 + 三点
            Image(nsImage: MenuBarIconRenderer.shieldIcon())
        }
    }
}

// MARK: - Menu Bar 图标渲染器

/// 使用 NSImage + NSBezierPath 绘制 Menu Bar 模板图标
enum MenuBarIconRenderer {
    
    /// 盾牌 + 三圆点（常规态 / 检测态）
    static func shieldIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let w = rect.width
            let h = rect.height
            
            NSColor.black.setStroke()
            NSColor.black.setFill()
            
            // 盾牌路径
            let shield = NSBezierPath()
            shield.move(to: NSPoint(x: w * 0.5, y: h * 0.94))   // 顶部中心（flipped 坐标）
            shield.line(to: NSPoint(x: w * 0.88, y: h * 0.76))
            shield.line(to: NSPoint(x: w * 0.88, y: h * 0.48))
            shield.curve(to: NSPoint(x: w * 0.5, y: h * 0.06),
                         controlPoint1: NSPoint(x: w * 0.88, y: h * 0.22),
                         controlPoint2: NSPoint(x: w * 0.72, y: h * 0.10))
            shield.curve(to: NSPoint(x: w * 0.12, y: h * 0.48),
                         controlPoint1: NSPoint(x: w * 0.28, y: h * 0.10),
                         controlPoint2: NSPoint(x: w * 0.12, y: h * 0.22))
            shield.line(to: NSPoint(x: w * 0.12, y: h * 0.76))
            shield.close()
            shield.lineWidth = 1.2
            shield.lineJoinStyle = .round
            shield.stroke()
            
            // 三个圆点（从下到上：flipped 坐标系）
            let dotR: CGFloat = w * 0.08
            let dotPositions: [CGFloat] = [h * 0.68, h * 0.50, h * 0.32]
            for cy in dotPositions {
                let dotRect = NSRect(x: w * 0.5 - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
                NSBezierPath(ovalIn: dotRect).fill()
            }
            
            return true
        }
        image.isTemplate = true
        return image
    }
    
    /// 盾牌 + 环绕弧线（扫描态）— 弧线会被 SwiftUI rotationEffect 旋转
    static func scanningIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let w = rect.width
            let h = rect.height
            
            NSColor.black.setStroke()
            NSColor.black.setFill()
            
            // 内缩盾牌（留出弧线空间）
            let inset: CGFloat = 2
            let iw = w - inset * 2
            let ih = h - inset * 2
            
            let shield = NSBezierPath()
            shield.move(to: NSPoint(x: w * 0.5, y: inset + ih * 0.92))
            shield.line(to: NSPoint(x: inset + iw * 0.85, y: inset + ih * 0.74))
            shield.line(to: NSPoint(x: inset + iw * 0.85, y: inset + ih * 0.48))
            shield.curve(to: NSPoint(x: w * 0.5, y: inset + ih * 0.08),
                         controlPoint1: NSPoint(x: inset + iw * 0.85, y: inset + ih * 0.24),
                         controlPoint2: NSPoint(x: inset + iw * 0.70, y: inset + ih * 0.12))
            shield.curve(to: NSPoint(x: inset + iw * 0.15, y: inset + ih * 0.48),
                         controlPoint1: NSPoint(x: inset + iw * 0.30, y: inset + ih * 0.12),
                         controlPoint2: NSPoint(x: inset + iw * 0.15, y: inset + ih * 0.24))
            shield.line(to: NSPoint(x: inset + iw * 0.15, y: inset + ih * 0.74))
            shield.close()
            shield.lineWidth = 1.0
            shield.lineJoinStyle = .round
            shield.stroke()
            
            // 三圆点
            let dotR: CGFloat = iw * 0.07
            let dotYs: [CGFloat] = [inset + ih * 0.66, inset + ih * 0.50, inset + ih * 0.34]
            for cy in dotYs {
                let dotRect = NSRect(x: w * 0.5 - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
                NSBezierPath(ovalIn: dotRect).fill()
            }
            
            // 环绕弧线（两段对称弧）
            let center = NSPoint(x: w * 0.5, y: h * 0.5)
            let radius = min(w, h) * 0.47
            
            let arc1 = NSBezierPath()
            arc1.appendArc(withCenter: center, radius: radius,
                           startAngle: 30, endAngle: 150, clockwise: false)
            arc1.lineWidth = 1.3
            arc1.lineCapStyle = .round
            arc1.stroke()
            
            let arc2 = NSBezierPath()
            arc2.appendArc(withCenter: center, radius: radius,
                           startAngle: 210, endAngle: 330, clockwise: false)
            arc2.lineWidth = 1.3
            arc2.lineCapStyle = .round
            arc2.stroke()
            
            return true
        }
        image.isTemplate = true
        return image
    }
}

