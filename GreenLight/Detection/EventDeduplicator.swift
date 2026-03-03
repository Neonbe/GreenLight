import Foundation

/// 双通道事件去重器
/// 以 app 路径（规范化后）为 key，3 秒时间窗口内的重复事件合并
class EventDeduplicator {
    private var pending: [String: PendingEvent] = [:]
    private let windowDuration: TimeInterval
    
    /// 串行队列：保护 pending 字典的所有读写（修复多线程并发崩溃）
    private let queue = DispatchQueue(label: "com.greenlight.deduplicator")
    
    /// 窗口到期后触发
    var onEvent: ((GreenLightEvent) -> Void)?
    
    private struct PendingEvent {
        var event: DetectionEvent
        var sources: Set<DetectionEvent.Source>
        let timestamp: Date
        var timer: DispatchWorkItem?
    }
    
    init(windowDuration: TimeInterval = 1.0) {  // §3.2 优化：3s→1s
        self.windowDuration = windowDuration
    }
    
    func receive(_ event: DetectionEvent) {
        queue.async { [weak self] in
            self?.performReceive(event)
        }
    }
    
    /// 实际的 receive 逻辑，始终在 queue 上执行
    private func performReceive(_ event: DetectionEvent) {
        let key = normalizePath(event.appPath.path)
        
        if var existing = pending[key] {
            // 窗口内追加来源
            existing.sources.insert(event.source)
            // 如果新事件有 bundleId 而旧的没有，更新
            if event.bundleId != nil && existing.event.bundleId == nil {
                existing.event = DetectionEvent(
                    source: event.source,
                    appPath: event.appPath,
                    bundleId: event.bundleId,
                    timestamp: existing.event.timestamp
                )
            }
            pending[key] = existing
            GLLog.dedup.info("Dedup merge: \(key), added source=\(String(describing: event.source)), total=\(existing.sources.count)")
        } else {
            // 新路径，开始窗口
            let timer = DispatchWorkItem { [weak self] in
                self?.flush(key: key)
            }
            pending[key] = PendingEvent(
                event: event,
                sources: [event.source],
                timestamp: event.timestamp,
                timer: timer
            )
            // timer 也在同一串行队列上触发，保证线程安全
            queue.asyncAfter(deadline: .now() + windowDuration, execute: timer)
            GLLog.dedup.info("Dedup new: \(key), source=\(String(describing: event.source)), window=\(self.windowDuration)s")
        }
    }
    
    /// flush 已在 queue 上被 timer 触发，无需额外同步
    private func flush(key: String) {
        guard let entry = pending.removeValue(forKey: key) else { return }
        
        let appPath = entry.event.appPath
        let appName = extractAppName(from: appPath)
        
        let greenLightEvent = GreenLightEvent(
            appPath: appPath,
            appName: appName,
            bundleId: entry.event.bundleId,
            sources: entry.sources,
            timestamp: entry.timestamp
        )
        GLLog.dedup.info("Dedup flush: \(appName), sources=\(entry.sources.map { String(describing: $0) }), bundleId=\(entry.event.bundleId ?? "nil")")
        onEvent?(greenLightEvent)
    }
    
    /// 路径规范化（解析符号链接、统一尾部斜线）
    private func normalizePath(_ path: String) -> String {
        var normalized = (path as NSString).resolvingSymlinksInPath
        // 统一移除尾部斜线
        while normalized.hasSuffix("/") && normalized.count > 1 {
            normalized = String(normalized.dropLast())
        }
        return normalized
    }
    
    /// 从 .app 路径提取应用名
    private func extractAppName(from url: URL) -> String {
        // 先尝试从 Info.plist 获取
        if let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        // 降级：从文件名提取
        return url.deletingPathExtension().lastPathComponent
    }
    
    /// 用于测试：清空所有 pending 事件
    func reset() {
        queue.sync {
            pending.values.forEach { $0.timer?.cancel() }
            pending.removeAll()
        }
    }
}
