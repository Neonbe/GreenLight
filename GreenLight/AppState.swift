import Foundation
import SwiftUI
import AppKit

/// 全局状态管理，驱动所有 UI 更新
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var blockedApps: [AppRecord] = []
    @Published var clearedApps: [AppRecord] = []
    @Published var totalGreenLights: Int = 0
    @Published var isScanning: Bool = false
    @Published var pendingPanelEvent: GreenLightEvent?
    
    private init() {
        load()
    }
    
    // MARK: - 事件处理
    
    /// 检测到新的被拦截应用
    func addBlockedApp(from event: GreenLightEvent) {
        // 检查是否已存在（更新后重新隔离的情况）
        if let existingIndex = clearedApps.firstIndex(where: { $0.path == event.appPath.path }) {
            // 从已放行移回被拦截
            var record = clearedApps.remove(at: existingIndex)
            record.status = .blocked
            record.firstDetected = event.timestamp
            blockedApps.append(record)
            GLLog.state.notice("Re-blocked (update): \(record.appName)")
        } else if blockedApps.contains(where: { $0.path == event.appPath.path }) {
            // 已经在被拦截列表中，忽略
            GLLog.state.debug("Already blocked, skip: \(event.appPath.path)")
            return
        } else {
            // 新 app
            var record = AppRecord(
                path: event.appPath.path,
                bundleId: event.bundleId,
                appName: event.appName,
                status: .blocked
            )
            record.appIcon = loadAppIcon(at: event.appPath)
            blockedApps.append(record)
            GLLog.state.notice("Blocked: \(event.appName), total=\(self.blockedApps.count)")
        }
        save()
    }
    
    /// 修复应用（移除 quarantine 成功后调用）
    func markAsCleared(_ record: AppRecord) {
        if let index = blockedApps.firstIndex(where: { $0.id == record.id }) {
            var updated = blockedApps.remove(at: index)
            updated.status = .cleared
            updated.greenLightCount += 1
            updated.lastFixed = Date()
            totalGreenLights += 1
            clearedApps.insert(updated, at: 0)
            GLLog.state.notice("Cleared: \(record.appName), greenLights=\(updated.greenLightCount), total=\(self.totalGreenLights)")
            save()
        }
    }
    
    /// 忽略应用（关闭通知但仍在列表）
    func dismissApp(_ record: AppRecord) {
        if let index = blockedApps.firstIndex(where: { $0.id == record.id }) {
            blockedApps[index].status = .dismissed
            GLLog.state.info("Dismissed: \(record.appName)")
            save()
        }
    }
    
    // MARK: - 持久化
    
    func save() {
        let allRecords = blockedApps + clearedApps
        Persistence.saveRecords(allRecords)
        Persistence.saveTotalGreenLights(totalGreenLights)
    }
    
    func load() {
        let records = Persistence.loadRecords()
        blockedApps = records.filter { $0.status == .blocked || $0.status == .dismissed }
        clearedApps = records.filter { $0.status == .cleared }
        totalGreenLights = Persistence.loadTotalGreenLights()
    }
    
    // MARK: - 辅助
    
    private func loadAppIcon(at url: URL) -> Data? {
        guard let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? else { return nil }
        icon.size = NSSize(width: 40, height: 40)
        guard let tiff = icon.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }
}
