import Foundation
import UserNotifications

/// 系统通知管理器（可选增强）
/// 降级为单例，仅在有系统通知权限时发送通知
/// 主通知通道已改为 DetectionPanelController
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    static let categoryIdentifier = "GREENLIGHT_DETECTION"
    
    enum Action: String {
        case dismiss = "DISMISS_ACTION"
        case fix = "FIX_ACTION"
        case fixAndOpen = "FIX_AND_OPEN_ACTION"
    }
    
    private let remover = QuarantineRemover()
    private var isAuthorized = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - 权限检查
    
    /// 异步检查当前通知权限状态
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            self?.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                GLLog.notification.notice("Notification permission: authorized (granted=true)")
                registerCategories()
            } else {
                GLLog.notification.error("Notification permission denied by user")
            }
            return granted
        } catch {
            GLLog.notification.error("Notification permission: failed (\(error))")
            return false
        }
    }
    
    // MARK: - 注册
    
    func registerCategories() {
        let dismissAction = UNNotificationAction(
            identifier: Action.dismiss.rawValue,
            title: String(localized: "notification.action.dismiss")
        )
        let fixAction = UNNotificationAction(
            identifier: Action.fix.rawValue,
            title: String(localized: "notification.action.fix")
        )
        let fixAndOpenAction = UNNotificationAction(
            identifier: Action.fixAndOpen.rawValue,
            title: String(localized: "notification.action.fixAndOpen")
        )
        
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [dismissAction, fixAction, fixAndOpenAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // MARK: - 发送通知（带权限检查）
    
    /// 仅在有权限时发送检测通知，无权限则静默跳过
    func sendDetectionNotificationIfAuthorized(for event: GreenLightEvent) {
        guard isAuthorized else {
            GLLog.notification.debug("System notification skipped (not authorized)")
            return
        }
        sendDetectionNotification(for: event)
    }
    
    func sendDetectionNotification(for event: GreenLightEvent) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.detection.title")
        content.body = String(localized: "notification.detection.body \(event.appName)")
        content.categoryIdentifier = Self.categoryIdentifier
        content.sound = .default
        
        content.userInfo = [
            "appPath": event.appPath.path,
            "appName": event.appName,
            "bundleId": event.bundleId ?? ""
        ]
        
        let request = UNNotificationRequest(
            identifier: "detection-\(event.appPath.path.hashValue)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                GLLog.notification.error("System notification failed: \(error)")
            } else {
                GLLog.notification.info("System notification sent for: \(event.appName)")
            }
        }
    }
    
    /// 发送修复成功通知
    func sendSuccessNotification(appName: String) {
        guard isAuthorized else {
            GLLog.notification.debug("System notification skipped (not authorized)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.success.title \(appName)")
        content.body = String(localized: "notification.success.body \(appName)")
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "success-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                GLLog.notification.error("System notification failed: \(error)")
            } else {
                GLLog.notification.info("System notification sent: greenlight for \(appName)")
            }
        }
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
                // 通知忽略 → 不改变 app 状态（留在 detected 列表）
                GLLog.notification.info("Notification dismissed for: \(appName)")
                
            case Action.fix.rawValue:
                handleFix(appPath: appPath, appName: appName, shouldOpen: false)
                
            case Action.fixAndOpen.rawValue:
                handleFix(appPath: appPath, appName: appName, shouldOpen: true)
                
            case UNNotificationDefaultActionIdentifier:
                break
                
            default:
                break
            }
            
            completionHandler()
        }
    }
    
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
            if case .needsAdmin(let message, _) = error {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "notification.failure.title")
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
