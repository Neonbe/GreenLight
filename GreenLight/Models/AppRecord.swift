import Foundation

struct AppRecord: Codable, Identifiable {
    let id: UUID
    var path: String
    var bundleId: String?
    var appName: String
    var appIcon: Data?
    var status: Status
    var greenLightCount: Int
    var firstDetected: Date
    var lastFixed: Date?
    var lastPanelShownAt: Date?   // §5.2: 上次弹面板时间（用于重弹冷却）
    var rejectedDate: Date?       // §7.1: 被丢弃的时间（用于 30天清理）
    
    enum Status: String, Codable {
        case detected  // 🟡 扫描/检测发现，待用户决策
        case rejected  // 🔴 用户主动丢到垃圾箱
        case cleared   // 🟢 已放行（quarantine 已移除）
    }
    
    init(path: String, bundleId: String? = nil, appName: String, status: Status = .detected) {
        self.id = UUID()
        self.path = path
        self.bundleId = bundleId
        self.appName = appName
        self.status = status
        self.greenLightCount = 0
        self.firstDetected = Date()
    }
}
