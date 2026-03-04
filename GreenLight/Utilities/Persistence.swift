import Foundation

/// UserDefaults 持久化工具
enum Persistence {
    private static let appRecordsKey = "greenlight.appRecords"
    private static let totalGreenLightsKey = "greenlight.totalGreenLights"
    private static let hasCompletedOnboardingKey = "greenlight.hasCompletedOnboarding"
    private static let lastEnhancePromptDateKey = "greenlight.lastEnhancePromptDate"
    private static let level1GrantedKey = "greenlight.level1Granted"
    
    // MARK: - AppRecords
    
    static func saveRecords(_ records: [AppRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: appRecordsKey)
            GLLog.state.debug("Saved \(records.count) records, totalGreenLights=\(loadTotalGreenLights())")
        } catch {
            GLLog.state.error("Failed to save records: \(error)")
        }
    }
    
    static func loadRecords() -> [AppRecord] {
        guard let data = UserDefaults.standard.data(forKey: appRecordsKey) else {
            return []
        }
        do {
            let records = try JSONDecoder().decode([AppRecord].self, from: data)
            let detected = records.filter { $0.status == .detected || $0.status == .rejected }.count
            let cleared = records.count - detected
            GLLog.state.debug("Loaded \(records.count) records (detected+rejected=\(detected), cleared=\(cleared))")
            return records
        } catch {
            // §9: 旧数据可能含 pending/blocked/dismissed，尝试迁移
            GLLog.state.warning("Decode failed, attempting migration: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                let migrated = jsonString
                    .replacingOccurrences(of: "\"pending\"", with: "\"detected\"")
                    .replacingOccurrences(of: "\"blocked\"", with: "\"detected\"")
                    .replacingOccurrences(of: "\"dismissed\"", with: "\"detected\"")
                if let migratedData = migrated.data(using: .utf8),
                   let records = try? JSONDecoder().decode([AppRecord].self, from: migratedData) {
                    GLLog.state.notice("Migration success: \(records.count) records recovered")
                    saveRecords(records)
                    return records
                }
            }
            GLLog.state.error("Failed to load records: \(error)")
            return []
        }
    }
    
    // MARK: - Total Green Lights
    
    static func saveTotalGreenLights(_ count: Int) {
        UserDefaults.standard.set(count, forKey: totalGreenLightsKey)
    }
    
    static func loadTotalGreenLights() -> Int {
        UserDefaults.standard.integer(forKey: totalGreenLightsKey)
    }
    
    // MARK: - Onboarding
    
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey) }
    }
    
    // MARK: - Enhance Prompt 冷却（§4.4）
    
    static var lastEnhancePromptDate: Date? {
        get {
            UserDefaults.standard.object(forKey: lastEnhancePromptDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastEnhancePromptDateKey)
        }
    }
    
    // MARK: - Level 1 授权标记
    
    /// 用户是否曾通过引导面板授权 Level 1 目录
    static var level1Granted: Bool {
        get { UserDefaults.standard.bool(forKey: level1GrantedKey) }
        set { UserDefaults.standard.set(newValue, forKey: level1GrantedKey) }
    }
}
