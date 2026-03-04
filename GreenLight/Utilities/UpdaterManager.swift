import Foundation
import Sparkle

/// Sparkle 自动更新封装
/// 将 SPUStandardUpdaterController 封装为 ObservableObject，供 SwiftUI 层使用。
///
/// ## 更新策略（A+B 双轨）
/// - **Plan A（静默）**：`automaticallyDownloadsUpdates = true`
///   → 后台静默下载 → 用户退出 App 时自动安装
/// - **Plan B（主动提示）**：`SparkleDelegate` 捕获新版本事件
///   → `availableUpdateVersion` 驱动 UI 显示"新版本可用"
///   → 用户点击"立即更新" → Sparkle 标准 UI 接管安装
@MainActor
final class UpdaterManager: ObservableObject {
    
    private let sparkleDelegate: SparkleDelegate
    private let updaterController: SPUStandardUpdaterController
    
    /// 是否可以立即检查更新（Sparkle 内部有冷却机制）
    @Published var canCheckForUpdates: Bool = false
    
    /// Updater 是否成功启动（密钥未配置时为 false）
    @Published private(set) var isUpdaterStarted: Bool = false
    
    /// Plan B：有新版本可用时的版本号（如 "1.1.0"），nil 表示当前已是最新
    @Published private(set) var availableUpdateVersion: String? = nil
    
    init() {
        // 1. 先创建 delegate（SPUStandardUpdaterController init 时需传入）
        let delegate = SparkleDelegate()
        self.sparkleDelegate = delegate
        
        // 2. 创建 controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        
        // 3. 设置 delegate 回调 → 更新 @Published 状态
        delegate.onUpdateFound = { [weak self] version in
            self?.availableUpdateVersion = version
            GLLog.state.info("Sparkle: new version available v\(version)")
        }
        delegate.onUpdateNotFound = { [weak self] in
            self?.availableUpdateVersion = nil
        }
        
        // 4. 监听 Sparkle 的 canCheckForUpdates 属性
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        
        // 5. 手动启动：仅在密钥已配置时尝试，错误只走日志不弹窗
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
        
        // Plan A：启用静默下载 → 退出时自动安装
        updaterController.updater.automaticallyDownloadsUpdates = true
        
        do {
            try updaterController.updater.start()
            isUpdaterStarted = true
            GLLog.state.info("Sparkle updater started (auto-download enabled)")
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
    
    /// Plan B 入口：用户点击"立即更新"按钮
    /// 内部调用 checkForUpdates()，此时下载已完成，Sparkle 会直接弹出安装对话框
    func installUpdate() {
        GLLog.state.info("User triggered install update (v\(self.availableUpdateVersion ?? "?"))")
        checkForUpdates()
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

// MARK: - SparkleDelegate

/// Sparkle 更新事件回调 → 通过闭包转发给 UpdaterManager
/// 独立类：因为 SPUStandardUpdaterController init 时需传入 delegate，
/// 而 UpdaterManager 此时尚未完成初始化（self 不可用）
final class SparkleDelegate: NSObject, SPUUpdaterDelegate {
    
    /// 发现新版本时回调（参数：displayVersionString，如 "1.1.0"）
    var onUpdateFound: (@MainActor (String) -> Void)?
    
    /// 未发现新版本时回调
    var onUpdateNotFound: (@MainActor () -> Void)?
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in
            onUpdateFound?(version)
        }
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            onUpdateNotFound?()
        }
    }
}
