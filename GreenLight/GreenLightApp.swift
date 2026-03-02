import SwiftUI

@main
struct GreenLightApp: App {
    @StateObject private var appState = AppState.shared
    @State private var showOnboarding = !Persistence.hasCompletedOnboarding
    
    private let notificationManager = NotificationManager()
    private let logMonitor = LogStreamMonitor()
    private let fsWatcher = FSEventsWatcher()
    private let deduplicator = EventDeduplicator()
    private let remover = QuarantineRemover()
    
    init() {
        setupPipeline()
    }
    
    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(appState)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .environmentObject(appState)
                }
        } label: {
            MenuBarLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    // MARK: - 检测管线搭建
    
    private func setupPipeline() {
        // 通知 Category 注册
        notificationManager.registerCategories()
        
        // Channel A → EventDeduplicator
        logMonitor.onDetection = { [deduplicator] event in
            deduplicator.receive(event)
        }
        
        // Channel B → EventDeduplicator
        fsWatcher.onDetection = { [deduplicator] event in
            deduplicator.receive(event)
        }
        
        // EventDeduplicator → 通知 + 状态更新
        deduplicator.onEvent = { [notificationManager] event in
            Task { @MainActor in
                let appState = AppState.shared
                appState.addBlockedApp(from: event)
                
                // 检查是否已被忽略（dismissed），如果是则不推送通知
                if let record = appState.blockedApps.first(where: { $0.path == event.appPath.path }),
                   record.status == .dismissed {
                    return
                }
                
                notificationManager.sendDetectionNotification(for: event)
            }
        }
        
        // 启动双通道检测
        logMonitor.startMonitoring()
        
        let dirs = Persistence.loadMonitoredDirectories() ?? FSEventsWatcher.defaultDirectories
        fsWatcher.startWatching(directories: dirs)
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
