import Foundation
import CoreServices

/// Channel B: 文件系统监控，检测新出现的带 quarantine 属性的 .app
class FSEventsWatcher: ObservableObject {
    private var stream: FSEventStreamRef?
    @Published var isRunning = false
    
    /// 检测到事件时的回调
    var onDetection: ((DetectionEvent) -> Void)?
    
    /// 内部去重（3 秒窗口）
    private var recentPaths: [String: Date] = [:]
    private let deduplicationWindow: TimeInterval = 3.0
    
    /// 默认监控目录
    static let defaultDirectories: [URL] = [
        URL.homeDirectory.appending(path: "Downloads"),
        URL.homeDirectory.appending(path: "Desktop"),
        URL(fileURLWithPath: "/Applications")
    ]
    
    // MARK: - 启停
    
    func startWatching(directories: [URL]? = nil) {
        guard !isRunning else { return }
        let dirs = directories ?? Self.defaultDirectories
        let paths = dirs.map(\.path) as CFArray
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency: 1秒
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            GLLog.fsEvents.fault("Failed to create FSEventStream for paths=\(dirs.map(\.path))")
            return
        }
        
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        isRunning = true
        GLLog.fsEvents.notice("FSEvents started, directories=\(dirs.count), paths=\(dirs.map(\.path))")
    }
    
    func stopWatching() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        isRunning = false
        GLLog.fsEvents.info("FSEvents stopped")
    }
    
    // MARK: - xattr 检查（C API，零 shell 依赖）
    
    static func hasQuarantine(at path: String) -> Bool {
        return getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) > 0
    }
    
    // MARK: - 快速扫描
    
    func scanApps(in directories: [URL]? = nil) -> [DetectionEvent] {
        let dirs = directories ?? Self.defaultDirectories
        var results: [DetectionEvent] = []
        let fm = FileManager.default
        
        GLLog.fsEvents.info("Scan started, directories=\(dirs.count)")
        
        for dir in dirs {
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                // 跳过 .app 内部（不递归进入 bundle）
                enumerator.skipDescendants()
                
                if Self.hasQuarantine(at: fileURL.path) {
                    GLLog.fsEvents.info("Scan found: \(fileURL.lastPathComponent)")
                    results.append(DetectionEvent(
                        source: .fsEvents,
                        appPath: fileURL,
                        bundleId: Bundle(url: fileURL)?.bundleIdentifier,
                        timestamp: Date()
                    ))
                }
            }
        }
        
        GLLog.fsEvents.notice("Scan completed: \(results.count) quarantined apps found")
        return results
    }
    
    // MARK: - 事件处理
    
    func handleFSEvent(path: String, flags: FSEventStreamEventFlags) {
        // 只关注 .app
        guard path.contains(".app") else { return }
        
        GLLog.fsEvents.debug("FS event: \(path), flags=\(flags)")
        
        // 提取 .app 路径
        guard let appPath = extractAppPath(from: path) else {
            GLLog.fsEvents.debug("FS event: failed to extract .app path from: \(path)")
            return
        }
        
        // 内部去重（3 秒窗口）
        let now = Date()
        if let lastSeen = recentPaths[appPath], now.timeIntervalSince(lastSeen) < deduplicationWindow {
            let elapsed = String(format: "%.1f", now.timeIntervalSince(lastSeen))
            GLLog.fsEvents.debug("FSEvents dedup: skipped \(appPath) (\(elapsed)s < 3s window)")
            return
        }
        recentPaths[appPath] = now
        
        // 清理过期记录
        recentPaths = recentPaths.filter { now.timeIntervalSince($0.value) < deduplicationWindow }
        
        // 检查 quarantine 属性
        guard Self.hasQuarantine(at: appPath) else {
            GLLog.fsEvents.debug("Quarantine check: \(appPath), hasQuarantine=false, skipped")
            return
        }
        
        let appURL = URL(fileURLWithPath: appPath)
        let bundleId = Bundle(url: appURL)?.bundleIdentifier
        GLLog.fsEvents.info("FSEvents detected: \(appURL.lastPathComponent), bundleId=\(bundleId ?? "nil")")
        
        let event = DetectionEvent(
            source: .fsEvents,
            appPath: appURL,
            bundleId: bundleId,
            timestamp: now
        )
        onDetection?(event)
    }
    
    private func extractAppPath(from path: String) -> String? {
        guard let range = path.range(of: ".app") else { return nil }
        return String(path[path.startIndex..<range.upperBound])
    }
}

// MARK: - FSEventStream C 回调

private func fsEventsCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue()
    
    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
    for i in 0..<numEvents {
        watcher.handleFSEvent(path: paths[i], flags: eventFlags[i])
    }
}
