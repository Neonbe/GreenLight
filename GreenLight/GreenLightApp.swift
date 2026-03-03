import SwiftUI
import AppKit

@main
struct GreenLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState.shared
    
    
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
            MainWindowView()
                .environmentObject(appState)
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
            PopoverView(enhanceManager: enhanceManager)
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
        }
    }
    
    // MARK: - 检测管线搭建（§五）
    
    private func setupPipeline() {
        // Channel A → EventDeduplicator
        logMonitor.onDetection = { [deduplicator, enhanceManager] event in
            // 标记窗口内有成功检测（§5.2）
            enhanceManager.markDetection()
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
        
        // EventDeduplicator → 浮动面板 + 状态更新
        deduplicator.onEvent = { event in
            Task { @MainActor in
                let latencyMs = Int(Date().timeIntervalSince(event.timestamp) * 1000)
                GLLog.pipeline.info("Pipeline received: \(event.appName), sources=\(event.sources.map { String(describing: $0) }), latency=\(latencyMs)ms")
                
                let appState = AppState.shared
                appState.addBlockedApp(from: event)
                
                // 弹出检测浮动面板
                GLLog.pipeline.info("Showing panel for: \(event.appName)")
                DetectionPanelController.shared.show(event: event)
                
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
        
        // onGKActivity → 置信度记录 + Level 0 兜底扫描（§3.5 目标化 + 120s 冷却）
        var fallbackScanTimer: DispatchWorkItem?
        var lastFallbackScanTime: Date?
        let fallbackCooldown: TimeInterval = 120  // §3.5: 120 秒冷却
        logMonitor.onGKActivity = { [fsWatcher, deduplicator, enhanceManager] in
            // 记录 GK 活动到置信度窗口
            enhanceManager.recordGKActivity()
            
            // 120 秒冷却检查
            if let lastScan = lastFallbackScanTime {
                let elapsed = Date().timeIntervalSince(lastScan)
                if elapsed < fallbackCooldown {
                    let remaining = Int(fallbackCooldown - elapsed)
                    GLLog.pipeline.debug("Fallback scan skipped: cooldown (\(remaining)s remaining)")
                    return
                }
            }
            
            // Level 0 兜底扫描（500ms 去抖，目标化扫描 recentCandidates）
            fallbackScanTimer?.cancel()
            let work = DispatchWorkItem {
                GLLog.pipeline.info("Fallback scan triggered by GK Prompt shown")
                lastFallbackScanTime = Date()
                let events = fsWatcher.scanApps()
                for event in events {
                    deduplicator.receive(event)
                }
                if events.isEmpty {
                    GLLog.pipeline.debug("Fallback scan: no rejected apps found")
                }
            }
            fallbackScanTimer = work
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5, execute: work)
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
    
    var body: some View {
        let blockedCount = appState.blockedApps.filter { $0.status != .dismissed || $0.status == .blocked }.count
        
        if blockedCount > 0 {
            Label("\(blockedCount)", systemImage: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.red)
        } else if appState.isScanning {
            Image(systemName: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow)
        } else {
            Image(systemName: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.green)
        }
    }
}
