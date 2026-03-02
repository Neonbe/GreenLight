import Foundation

/// 分级权限请求管理器（§三）
/// 管理 T1（被动）和 T2（主动）触发，置信度窗口和冷却逻辑
/// 独立于 UI，便于单元测试
class EnhancePromptManager {
    
    enum Trigger {
        case t1  // GK 活动兜底（被动）
        case t2  // 用户手动操作（主动）
    }
    
    // MARK: - 回调
    
    /// 需要显示引导面板时调用
    var onShowEnhancePanel: (() -> Void)?
    
    /// Level 1 升级时调用（参数为已授权的目录列表）
    var onUpgradeToLevel1: (([URL]) -> Void)?
    
    // MARK: - T1 置信度窗口（§3.6）
    
    struct GKWindow {
        let start: Date
        var count: Int
        var hasDetection: Bool
    }
    
    /// 置信度窗口（可测试访问）
    private(set) var gkActivityWindow: GKWindow?
    
    /// 窗口时长（秒），默认 10s
    let windowDuration: TimeInterval
    
    /// 最少 GK 活动次数
    let minGKCount: Int
    
    // MARK: - 冷却（§3.5）
    
    /// 会话级：用户点击 "Not Now" 后，本次 App 运行期间 T1 不再触发
    private(set) var sessionDismissedEnhancePrompt = false
    
    /// 全局冷却时长（秒），默认 24h
    let globalCooldown: TimeInterval
    
    /// 所有 TCC 目录是否都已被系统拒绝（实时探测确认后设置）
    private(set) var allDirectoriesDenied = false
    
    // MARK: - 窗口到期调度（可注入测试替身）
    
    /// 调度器：延迟执行窗口到期检查，可在测试中替换为同步实现
    var scheduleWindowExpiry: (@escaping () -> Void, TimeInterval) -> Void = { block, delay in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }
    
    /// TCC 权限检查，可在测试中替换为返回 false 的实现
    var checkDirectoryAccess: (URL) -> Bool = { FSEventsWatcher.canAccessDirectory($0) }
    
    // MARK: - Init
    
    init(windowDuration: TimeInterval = 10.0,
         minGKCount: Int = 2,
         globalCooldown: TimeInterval = 86400) {
        self.windowDuration = windowDuration
        self.minGKCount = minGKCount
        self.globalCooldown = globalCooldown
    }
    
    // MARK: - T1: GK 活动记录（§5.2）
    
    /// 记录一次 GK 活动（无路径提取）
    func recordGKActivity() {
        let now = Date()
        
        if var window = gkActivityWindow,
           now.timeIntervalSince(window.start) < windowDuration {
            // 在窗口内，累加
            window.count += 1
            gkActivityWindow = window
            GLLog.enhance.debug("GK window: count=\(window.count), hasDetection=\(window.hasDetection)")
        } else {
            // 新窗口
            gkActivityWindow = GKWindow(start: now, count: 1, hasDetection: false)
            GLLog.enhance.debug("GK window started")
            
            // 窗口到期检查
            scheduleWindowExpiry({ [weak self] in
                self?.evaluateGKWindow()
            }, windowDuration)
        }
    }
    
    /// 标记窗口内有成功检测（Channel A 提取到了路径）
    func markDetection() {
        gkActivityWindow?.hasDetection = true
        GLLog.enhance.debug("GK window: detection marked")
    }
    
    /// 窗口到期评估
    private func evaluateGKWindow() {
        guard let window = gkActivityWindow else { return }
        
        GLLog.enhance.info("GK window expired: count=\(window.count), hasDetection=\(window.hasDetection), threshold=\(self.minGKCount)")
        
        // 置信度门槛：≥ minGKCount 次 GK 活动 + 0 次成功检测
        if window.count >= minGKCount && !window.hasDetection {
            if canShowPrompt(forTrigger: .t1) {
                GLLog.enhance.notice("T1 threshold met, showing enhance panel")
                Persistence.lastEnhancePromptDate = Date()
                onShowEnhancePanel?()
            } else {
                GLLog.enhance.info("T1 threshold met but cooldown active, suppressed")
            }
        }
        
        gkActivityWindow = nil
    }
    
    // MARK: - 冷却检查（§3.5）
    
    /// 检查是否可以显示引导面板
    func canShowPrompt(forTrigger trigger: Trigger) -> Bool {
        // 所有目录被拒 → 不再弹
        if allDirectoriesDenied {
            GLLog.enhance.debug("canShowPrompt: all directories denied")
            return false
        }
        
        // 已全部授权 → 不需要弹
        let ungrantedDirs = FSEventsWatcher.level1Directories.filter {
            !checkDirectoryAccess($0)
        }
        if ungrantedDirs.isEmpty {
            GLLog.enhance.debug("canShowPrompt: all directories already granted")
            return false
        }
        
        switch trigger {
        case .t2:
            // T2 永远不受冷却限制
            return true
            
        case .t1:
            // 会话级节流
            if sessionDismissedEnhancePrompt {
                GLLog.enhance.debug("canShowPrompt: session dismissed")
                return false
            }
            
            // 全局冷却（24h）
            if let lastDate = Persistence.lastEnhancePromptDate,
               Date().timeIntervalSince(lastDate) < globalCooldown {
                GLLog.enhance.debug("canShowPrompt: global cooldown active")
                return false
            }
            
            return true
        }
    }
    
    // MARK: - 用户操作
    
    /// 用户点击 "Not Now"（§3.3）
    func dismissedByUser() {
        sessionDismissedEnhancePrompt = true
        GLLog.enhance.info("User dismissed enhance prompt (session)")
    }
    
    /// T2: 用户主动请求（扫描按钮 / Expand Coverage）
    func requestEnhance() {
        GLLog.enhance.notice("T2 triggered: user requested enhance")
        
        if canShowPrompt(forTrigger: .t2) {
            attemptUpgradeToLevel1()
        }
    }
    
    // MARK: - Level 1 升级（§4.3）
    
    /// 探测 TCC 权限，触发未授权目录的文件访问，追加已授权目录
    func attemptUpgradeToLevel1() {
        var grantedDirs: [URL] = []
        var deniedCount = 0
        
        for dir in FSEventsWatcher.level1Directories {
            if checkDirectoryAccess(dir) {
                grantedDirs.append(dir)
                GLLog.enhance.info("TCC granted: \(dir.path)")
            } else {
                deniedCount += 1
                GLLog.enhance.info("TCC denied: \(dir.path)")
            }
        }
        
        if deniedCount == FSEventsWatcher.level1Directories.count {
            allDirectoriesDenied = true
            GLLog.enhance.notice("All Level 1 directories denied, will not prompt again")
        }
        
        if !grantedDirs.isEmpty {
            GLLog.enhance.notice("Upgrading to Level 1: \(grantedDirs.map(\.path))")
            onUpgradeToLevel1?(grantedDirs)
        }
    }
    
    // MARK: - 重置（测试用）
    
    func reset() {
        gkActivityWindow = nil
        sessionDismissedEnhancePrompt = false
        allDirectoriesDenied = false
    }
}
