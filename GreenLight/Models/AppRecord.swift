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
    
    enum Status: String, Codable {
        case pending    // 🟡 等待去重
        case blocked    // 🔴 被拦截，待处理
        case dismissed  // 🔴 用户点了忽略，仍在列表但不再推送通知
        case cleared    // 🟢 已放行
    }
    
    init(path: String, bundleId: String? = nil, appName: String, status: Status = .pending) {
        self.id = UUID()
        self.path = path
        self.bundleId = bundleId
        self.appName = appName
        self.status = status
        self.greenLightCount = 0
        self.firstDetected = Date()
    }
}
