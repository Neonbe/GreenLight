import SwiftUI
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
                DispatchQueue.global(qos: .userInitiated).async {
                    fsWatcher.warmupScan()
                }
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
        
        // §r06: 启动预热扫描（轻量 SecStaticCode，仅填充 L2 缓存）
        if Persistence.hasCompletedOnboarding {
            // 非首次启动：立即预热
            DispatchQueue.global(qos: .userInitiated).async { [fsWatcher] in
                fsWatcher.warmupScan()
            }
        }
        // 首次启动：由 OnboardingView BrandStep.onAppear 触发预热（见 §2.1）
        
        // onGKActivity → §r06 确认态流程 + 置信度记录 + fallback 兜底
        var lastProactiveScanTime: Date?
        let proactiveScanCooldown: TimeInterval = 5
        var fallbackScanTimer: DispatchWorkItem?
        var lastFallbackScanTime: Date?
        let fallbackCooldown: TimeInterval = 120
        var confirmTimeoutWork: DispatchWorkItem?
        
        logMonitor.onGKActivity = { [fsWatcher, deduplicator, enhanceManager] in
            
            // §r06: Menu Bar 黄灯
            Task { @MainActor in
                AppState.shared.isScanning = true
            }
            
            // §r06 Channel C: 主动扫描 → 确认态面板
            let now = Date()
            if let lastScan = lastProactiveScanTime, now.timeIntervalSince(lastScan) < proactiveScanCooldown {
                let remaining = String(format: "%.1f", proactiveScanCooldown - now.timeIntervalSince(lastScan))
                GLLog.pipeline.debug("proactiveScan skipped: cooldown (\(remaining)s remaining)")
            } else {
                lastProactiveScanTime = now
                DispatchQueue.global(qos: .userInitiated).async {
                    let events = fsWatcher.proactiveScan(knownPaths: [])
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
                    
                    // 5s 超时兜底：用 proactiveScan 首个结果替换
                    confirmTimeoutWork?.cancel()
                    let timeoutWork = DispatchWorkItem {
                        Task { @MainActor in
                            guard DetectionPanelController.shared.isConfirming else { return }
                            let first = sortedEvents[0]
                            let appName = first.appPath.deletingPathExtension().lastPathComponent
                            let greenLightEvent = GreenLightEvent(
                                appPath: first.appPath,
                                appName: appName,
                                bundleId: first.bundleId,
                                sources: [.proactiveScan],
                                timestamp: first.timestamp
                            )
                            GLLog.pipeline.notice("proactiveScan timeout fallback: \(appName)")
                            let appState = AppState.shared
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

/// Menu Bar 图标标签
struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false
    
    var body: some View {
        let detectedCount = appState.detectedApps.count  // §6.4: badge 显示 🟡 待处理数
        
        if detectedCount > 0 {
            Label("\(detectedCount)", systemImage: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow)
        } else if appState.isScanning {
            Image(systemName: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow)
                .opacity(reduceMotion ? 1 : (isPulsing ? 0.6 : 1.0))
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
                .onChange(of: appState.isScanning) { scanning in
                    if !scanning { isPulsing = false }
                }
        } else {
            Image(systemName: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.green)
        }
    }
}
