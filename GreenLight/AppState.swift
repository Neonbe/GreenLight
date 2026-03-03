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
    
    /// Menu Bar Extra 点击 app icon → 主窗口自动弹出 ActionBubble
    @Published var pendingSelectedApp: AppRecord?
    
    /// 🟡 待处理的应用（扫描/检测发现，文件仍存在）
    var detectedApps: [AppRecord] {
        blockedApps.filter { $0.status == .detected && FileManager.default.fileExists(atPath: $0.path) }
    }
    
    /// 🔴 用户丢弃的应用（占位符记录）
    var rejectedApps: [AppRecord] { blockedApps.filter { $0.status == .rejected } }
    
    private init() {
        load()
    }
    
    // MARK: - 事件处理
    
    /// 检测到新应用 → 进入 🟡 detected（§3.1: 所有来源统一）
    func addDetectedApp(from event: GreenLightEvent) {
        // 已在 🟢 cleared → 移回 🟡（更新后重新隔离）
        if let existingIndex = clearedApps.firstIndex(where: { $0.path == event.appPath.path }) {
            var record = clearedApps.remove(at: existingIndex)
            record.status = .detected
            record.firstDetected = event.timestamp
            blockedApps.append(record)
            GLLog.state.notice("Re-detected (update): \(record.appName)")
        } else if let existingIndex = blockedApps.firstIndex(where: { $0.path == event.appPath.path }) {
            // §3.2: 已在列表中 → 跳过（不重复添加）
            let existing = blockedApps[existingIndex]
            GLLog.state.debug("Already in list (\(existing.status.rawValue)), skip: \(event.appName)")
            return
        } else {
            // 新 app → 🟡 detected
            var record = AppRecord(
                path: event.appPath.path,
                bundleId: event.bundleId,
                appName: event.appName,
                status: .detected
            )
            record.appIcon = loadAppIcon(at: event.appPath)
            blockedApps.append(record)
            GLLog.state.notice("Detected: \(event.appName), total=\(self.blockedApps.count)")
        }
        save()
    }
    
    /// 放行应用 → 🟢 cleared（移除 quarantine 成功后调用）
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
    
    /// 标记应用为 🔴 rejected（文件已从磁盘消失，被动观察到的用户丢弃行为）
    func markAsRejected(_ record: AppRecord) {
        if let index = blockedApps.firstIndex(where: { $0.id == record.id }) {
            blockedApps[index].status = .rejected
            blockedApps[index].rejectedDate = Date()
            GLLog.state.notice("Rejected (file gone): \(record.appName)")
            save()
        }
    }
    
    /// 被动检测：遍历 🟡 列表，文件不存在的记录 → 🔴 rejected
    /// 触发时机：FSEvents 变更、扫描完成、App 启动
    func reconcileDetectedApps() {
        var changed = false
        for (index, record) in blockedApps.enumerated() where record.status == .detected {
            if !FileManager.default.fileExists(atPath: record.path) {
                blockedApps[index].status = .rejected
                blockedApps[index].rejectedDate = Date()
                GLLog.state.notice("Reconcile → rejected (file gone): \(record.appName)")
                changed = true
            }
        }
        if changed { save() }
    }
    
    /// 更新面板展示时间戳（§5.2: 面板重弹冷却）
    func updatePanelTimestamp(for path: String) {
        if let index = blockedApps.firstIndex(where: { $0.path == path }) {
            blockedApps[index].lastPanelShownAt = Date()
            save()
        }
    }
    
    /// §7.1: 清理 30 天前的 rejected 占位符
    func cleanupExpiredRejections() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let beforeCount = blockedApps.count
        blockedApps.removeAll { record in
            guard record.status == .rejected, let rejectedDate = record.rejectedDate else { return false }
            return rejectedDate < cutoff
        }
        let removed = beforeCount - blockedApps.count
        if removed > 0 {
            GLLog.state.notice("Cleanup: removed \(removed) expired rejected records")
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
        blockedApps = records.filter { $0.status == .detected || $0.status == .rejected }
        clearedApps = records.filter { $0.status == .cleared }
        totalGreenLights = Persistence.loadTotalGreenLights()
        // 启动时：清理过期 rejected + 标记文件已消失的 detected
        cleanupExpiredRejections()
        reconcileDetectedApps()
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
