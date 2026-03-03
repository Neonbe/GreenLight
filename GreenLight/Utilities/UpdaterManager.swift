import Foundation
import Sparkle

/// Sparkle 自动更新封装
/// 将 SPUStandardUpdaterController 封装为 ObservableObject，供 SwiftUI 层使用。
@MainActor
final class UpdaterManager: ObservableObject {
    
    private let updaterController: SPUStandardUpdaterController
    
    /// 是否可以立即检查更新（Sparkle 内部有冷却机制）
    @Published var canCheckForUpdates: Bool = false
    
    /// Updater 是否成功启动（密钥未配置时为 false）
    @Published private(set) var isUpdaterStarted: Bool = false
    
    init() {
        // startingUpdater: false → 不立即启动，由我们手动控制
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // 监听 Sparkle 的 canCheckForUpdates 属性
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        
        // 手动启动：仅在密钥已配置时尝试，错误只走日志不弹窗
        startUpdaterIfConfigured()
    }
    
    // MARK: - Private
    
    private func startUpdaterIfConfigured() {
        // 检测占位符 — 密钥未配置时静默跳过，不弹任何对话框
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if publicKey.isEmpty || publicKey.contains("YOUR_") {
            GLLog.state.warning("Sparkle: EdDSA key not configured, updater disabled")
            return
        }
        
        do {
            try updaterController.updater.start()
            isUpdaterStarted = true
            GLLog.state.info("Sparkle updater started successfully")
        } catch {
            // 仅日志输出，绝不弹窗给用户
            GLLog.state.error("Sparkle updater failed to start: \(error.localizedDescription)")
            #if DEBUG
            print("⚠️ [Sparkle] Updater failed to start: \(error)")
            #endif
        }
    }
    
    // MARK: - Public API
    
    /// 手动检查更新（用户点击"检查更新"按钮时调用）
    func checkForUpdates() {
        guard isUpdaterStarted else {
            GLLog.state.warning("Cannot check for updates: updater not started")
            return
        }
        updaterController.checkForUpdates(nil)
        GLLog.state.info("Manual update check triggered")
    }
    
    /// 是否自动检查更新
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set {
            updaterController.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
            GLLog.state.info("Auto update check: \(newValue)")
        }
    }
    
    /// 上次检查更新的时间
    var lastUpdateCheckDate: Date? {
        updaterController.updater.lastUpdateCheckDate
    }
}
