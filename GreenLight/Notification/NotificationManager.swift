import Foundation
import UserNotifications

/// 管理 UserNotifications 的注册、发送和用户响应
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    static let categoryIdentifier = "GREENLIGHT_DETECTION"
    
    enum Action: String {
        case dismiss = "DISMISS_ACTION"
        case fix = "FIX_ACTION"
        case fixAndOpen = "FIX_AND_OPEN_ACTION"
    }
    
    private let remover = QuarantineRemover()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - 注册
    
    func registerCategories() {
        let dismissAction = UNNotificationAction(
            identifier: Action.dismiss.rawValue,
            title: "❌ 忽略"
        )
        let fixAction = UNNotificationAction(
            identifier: Action.fix.rawValue,
            title: "🔓 修复"
        )
        let fixAndOpenAction = UNNotificationAction(
            identifier: Action.fixAndOpen.rawValue,
            title: "🛠 修复并打开"
        )
        
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [dismissAction, fixAction, fixAndOpenAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[NotificationManager] 权限请求失败: \(error)")
            return false
        }
    }
    
    // MARK: - 发送通知
    
    func sendDetectionNotification(for event: GreenLightEvent) {
        let content = UNMutableNotificationContent()
        content.title = "🚦 GreenLight"
        content.body = "macOS 拦截了 \(event.appName)"
        content.categoryIdentifier = Self.categoryIdentifier
        content.sound = .default
        
        // 存储 app 路径到 userInfo，供 Action 处理时使用
        content.userInfo = [
            "appPath": event.appPath.path,
            "appName": event.appName,
            "bundleId": event.bundleId ?? ""
        ]
        
        let request = UNNotificationRequest(
            identifier: "detection-\(event.appPath.path.hashValue)",
            content: content,
            trigger: nil // 立即发送
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[NotificationManager] 发送失败: \(error)") }
        }
    }
    
    /// 发送修复成功通知
    func sendSuccessNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "✅ 已为 \(appName) 亮绿灯"
        content.body = "\(appName) 已放行，可以正常使用了"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "success-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let appPathStr = userInfo["appPath"] as? String,
              let appName = userInfo["appName"] as? String else {
            completionHandler()
            return
        }
        
        let appPath = URL(fileURLWithPath: appPathStr)
        
        Task { @MainActor in
            let appState = AppState.shared
            
            switch response.actionIdentifier {
            case Action.dismiss.rawValue, UNNotificationDismissActionIdentifier:
                // 忽略：标记为 dismissed
                if let record = appState.blockedApps.first(where: { $0.path == appPathStr }) {
                    appState.dismissApp(record)
                }
                
            case Action.fix.rawValue:
                // 仅修复
                handleFix(appPath: appPath, appName: appName, shouldOpen: false)
                
            case Action.fixAndOpen.rawValue:
                // 修复并打开
                handleFix(appPath: appPath, appName: appName, shouldOpen: true)
                
            case UNNotificationDefaultActionIdentifier:
                // 点击通知本体 — 无特殊操作（会打开 popover）
                break
                
            default:
                break
            }
            
            completionHandler()
        }
    }
    
    // 允许前台展示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // MARK: - 修复逻辑
    
    @MainActor
    private func handleFix(appPath: URL, appName: String, shouldOpen: Bool) {
        let result = remover.removeQuarantine(at: appPath)
        let appState = AppState.shared
        
        switch result {
        case .success:
            if let record = appState.blockedApps.first(where: { $0.path == appPath.path }) {
                appState.markAsCleared(record)
            }
            sendSuccessNotification(appName: appName)
            if shouldOpen {
                remover.openApp(at: appPath)
            }
            
        case .failure(let error):
            // 发送失败通知（含终端命令提示）
            if case .needsAdmin(let message, _) = error {
                let content = UNMutableNotificationContent()
                content.title = "⚠️ 修复失败"
                content.body = message
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "failure-\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
}
