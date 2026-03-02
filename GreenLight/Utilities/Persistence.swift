import Foundation

/// UserDefaults 持久化工具
enum Persistence {
    private static let appRecordsKey = "greenlight.appRecords"
    private static let totalGreenLightsKey = "greenlight.totalGreenLights"
    private static let hasCompletedOnboardingKey = "greenlight.hasCompletedOnboarding"
    private static let monitoredDirectoriesKey = "greenlight.monitoredDirectories"
    
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
            let blocked = records.filter { $0.status == .blocked || $0.status == .dismissed }.count
            let cleared = records.count - blocked
            GLLog.state.debug("Loaded \(records.count) records (blocked=\(blocked), cleared=\(cleared))")
            return records
        } catch {
            GLLog.state.error("Failed to save records: \(error)")
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
    
    // MARK: - Monitored Directories
    
    static func saveMonitoredDirectories(_ dirs: [URL]) {
        let paths = dirs.map(\.path)
        UserDefaults.standard.set(paths, forKey: monitoredDirectoriesKey)
    }
    
    static func loadMonitoredDirectories() -> [URL]? {
        guard let paths = UserDefaults.standard.stringArray(forKey: monitoredDirectoriesKey) else {
            return nil
        }
        return paths.map { URL(fileURLWithPath: $0) }
    }
}
