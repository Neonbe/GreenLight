import SwiftUI

/// Onboarding 首次引导流程
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var isScanning = false
    @State private var scanResults: [DetectionEvent] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 页面内容
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                permissionPage.tag(1)
                scanPage.tag(2)
            }
            .tabViewStyle(.automatic)
            .frame(width: 480, height: 400)
        }
        .background(Color(nsColor: NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)))
    }
    
    // MARK: - 欢迎页
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("🚦")
                .font(.system(size: 64))
            
            Text("欢迎使用 GreenLight")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("自动检测被 Gatekeeper 拦截的应用\n一键放行，无需繁琐操作")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button("开始设置") {
                withAnimation { currentPage = 1 }
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 权限页
    
    private var permissionPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("开启通知权限")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("GreenLight 需要通知权限来提醒你\n当有应用被 macOS 拦截时，会立即通知你")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button("授权通知") {
                Task {
                    let manager = NotificationManager()
                    _ = await manager.requestAuthorization()
                    await MainActor.run {
                        withAnimation { currentPage = 2 }
                        startScan()
                    }
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 扫描页
    
    private var scanPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if isScanning {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                
                Text("正在扫描已安装应用…")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            } else {
                if scanResults.isEmpty {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("一切正常！")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("未发现被隔离的应用\nGreenLight 将在后台守护你")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("发现 \(scanResults.count) 个被隔离的应用")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // 列出被发现的 app
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(scanResults.prefix(5), id: \.appPath) { event in
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text(event.appPath.deletingPathExtension().lastPathComponent)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        if scanResults.count > 5 {
                            Text("…还有 \(scanResults.count - 5) 个")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
            
            if !isScanning {
                HStack(spacing: 12) {
                    if !scanResults.isEmpty {
                        Button("🟢 全部放行") {
                            fixAll()
                            finishOnboarding()
                        }
                        .buttonStyle(OnboardingButtonStyle())
                    }
                    
                    Button(scanResults.isEmpty ? "完成" : "逐个查看") {
                        finishOnboarding()
                    }
                    .buttonStyle(OnboardingButtonStyle(isPrimary: scanResults.isEmpty))
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - 扫描逻辑
    
    private func startScan() {
        isScanning = true
        Task.detached {
            let watcher = FSEventsWatcher()
            let results = watcher.scanApps()
            await MainActor.run {
                scanResults = results
                // 将扫描结果加入 AppState
                for event in results {
                    let glEvent = GreenLightEvent(
                        appPath: event.appPath,
                        appName: event.appPath.deletingPathExtension().lastPathComponent,
                        bundleId: event.bundleId,
                        sources: [.fsEvents],
                        timestamp: event.timestamp
                    )
                    appState.addBlockedApp(from: glEvent)
                }
                isScanning = false
            }
        }
    }
    
    private func fixAll() {
        let remover = QuarantineRemover()
        for app in appState.blockedApps {
            let result = remover.removeQuarantine(at: URL(fileURLWithPath: app.path))
            if case .success = result {
                appState.markAsCleared(app)
            }
        }
    }
    
    private func finishOnboarding() {
        Persistence.hasCompletedOnboarding = true
        isPresented = false
    }
}

struct OnboardingButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? Color.green : Color.white.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
