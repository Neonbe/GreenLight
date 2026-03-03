import Foundation
import CoreServices
import Security

/// Channel B: 文件系统监控，检测新出现的带 quarantine 属性的 .app
class FSEventsWatcher: ObservableObject {
    private var stream: FSEventStreamRef?
    @Published var isRunning = false
    
    /// 检测到事件时的回调
    var onDetection: ((DetectionEvent) -> Void)?
    
    /// 目录变更回调（任何 .app 的 FS 事件，含文件消失），用于触发 reconcile
    var onDirectoryChange: (() -> Void)?
    
    /// GK 判定器（可注入，便于测试）
    var assessor: GatekeeperAssessing = GatekeeperAssessor()
    
    /// 内部去重（3 秒窗口）
    private var recentPaths: [String: Date] = [:]
    private let deduplicationWindow: TimeInterval = 3.0
    
    /// §3.5: 近期候选路径（30 秒内有 FS 活动的 .app 路径），供目标化 fallback scan 使用
    private(set) var recentCandidates: [String: Date] = [:]
    private let candidateWindow: TimeInterval = 30.0
    
    /// §r06 L2 缓存：SecStaticCode 验证通过的 app（Key="路径|modDate"，串行队列保护）
    private let l2Queue = DispatchQueue(label: "com.greenlight.l2cache")
    private var _knownSafePaths: Set<String> = []
    
    private func containsSafePath(_ key: String) -> Bool {
        l2Queue.sync { _knownSafePaths.contains(key) }
    }
    private func insertSafePath(_ key: String) {
        l2Queue.sync { _knownSafePaths.insert(key) }
    }
    private var safeCacheCount: Int {
        l2Queue.sync { _knownSafePaths.count }
    }
    
    /// 当前监控中的目录列表
    private(set) var currentMonitoredDirectories: [URL] = []
    
    // MARK: - 目录分级（§六）
    
    /// Level 0: 零 TCC 依赖，App 启动即生效
    static let level0Directories: [URL] = [
        URL(fileURLWithPath: "/Applications")
    ]
    
    /// Level 1: 需 TCC 授权，场景驱动拉起
    static let level1Directories: [URL] = [
        URL.homeDirectory.appending(path: "Downloads"),
        URL.homeDirectory.appending(path: "Desktop")
    ]
    
    // MARK: - 启停
    
    func startWatching(directories: [URL]? = nil) {
        guard !isRunning else { return }
        let dirs = directories ?? Self.level0Directories
        currentMonitoredDirectories = dirs
        let paths = dirs.map(\.path) as CFArray
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency: 0.5秒（§3.1 优化）
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
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
        currentMonitoredDirectories = []
        GLLog.fsEvents.info("FSEvents stopped")
    }
    
    // MARK: - xattr 检查（C API，零 shell 依赖）
    
    static func hasQuarantine(at path: String) -> Bool {
        return getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) > 0
    }
    
    // MARK: - 目标化补漏扫描（§3.5）
    
    /// 目标化 scan：仅遍历 recentCandidates + spctl 二次确认
    func scanApps(in directories: [URL]? = nil) -> [DetectionEvent] {
        let now = Date()
        
        // 清理过期候选
        recentCandidates = recentCandidates.filter { now.timeIntervalSince($0.value) < candidateWindow }
        
        let candidates = Array(recentCandidates.keys)
        GLLog.fsEvents.info("Fallback scan: \(candidates.count) recent candidates")
        
        guard !candidates.isEmpty else { return [] }
        
        var results: [DetectionEvent] = []
        for path in candidates {
            guard Self.hasQuarantine(at: path) else { continue }
            
            let gkResult = assessor.assess(appPath: path)
            guard gkResult == .rejected else {
                GLLog.fsEvents.debug("Fallback scan: \(URL(fileURLWithPath: path).lastPathComponent), GK=\(String(describing: gkResult)), skipped")
                continue
            }
            
            let appURL = URL(fileURLWithPath: path)
            GLLog.fsEvents.info("Fallback scan found rejected: \(appURL.lastPathComponent)")
            results.append(DetectionEvent(
                source: .scan,
                appPath: appURL,
                bundleId: Bundle(url: appURL)?.bundleIdentifier,
                timestamp: now
            ))
        }
        
        GLLog.fsEvents.notice("Fallback scan completed: \(results.count) rejected apps found")
        return results
    }
    
    // MARK: - §r05 主动扫描（Channel C）
    
    /// GK evaluate 触发的主动扫描：遍历监控目录 → 三层过滤 → SecStaticCode 验签
    /// 仅用 SecStaticCode（~6ms），不走 spctl（~3s），失败即判定拦截
    func proactiveScan(knownPaths: Set<String>) -> [DetectionEvent] {
        let scanStart = Date()
        let dirs = currentMonitoredDirectories
        guard !dirs.isEmpty else { return [] }
        
        var results: [DetectionEvent] = []
        let fm = FileManager.default
        var l1Count = 0
        
        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            for item in contents where item.pathExtension == "app" {
                let path = item.path
                
                // L1: quarantine 预过滤（纳秒级）
                guard Self.hasQuarantine(at: path) else { continue }
                l1Count += 1
                
                // L3: 跳过 AppState 已知（blocked/dismissed/cleared）
                guard !knownPaths.contains(path) else { continue }
                
                // L2: knownSafePaths 缓存（Key=路径+modDate，线程安全）
                let modDate = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date)
                    ?? Date.distantPast
                let cacheKey = "\(path)|\(modDate.timeIntervalSince1970)"
                guard !containsSafePath(cacheKey) else { continue }
                
                // SecStaticCode 验签（仅此，不走 spctl）
                let cfURL = URL(fileURLWithPath: path) as CFURL
                var codeRef: SecStaticCode?
                let createStatus = SecStaticCodeCreateWithPath(cfURL, [], &codeRef)
                guard createStatus == errSecSuccess, let code = codeRef else {
                    // 无法创建代码对象 → 视为拦截
                    GLLog.fsEvents.info("proactiveScan found (no code): \(item.lastPathComponent)")
                    results.append(DetectionEvent(
                        source: .proactiveScan, appPath: item,
                        bundleId: Bundle(url: item)?.bundleIdentifier, timestamp: scanStart
                    ))
                    continue
                }
                
                // SecStaticCode 验签（完整校验，含资源验证）
                let checkStatus = SecStaticCodeCheckValidity(code, [], nil)
                if checkStatus != errSecSuccess {
                    // 签名无效 → 拦截
                    GLLog.fsEvents.info("proactiveScan found: \(item.lastPathComponent), OSStatus=\(checkStatus)")
                    results.append(DetectionEvent(
                        source: .proactiveScan, appPath: item,
                        bundleId: Bundle(url: item)?.bundleIdentifier, timestamp: scanStart
                    ))
                } else {
                    // 签名有效 → 加入 L2 缓存，后续跳过
                    insertSafePath(cacheKey)
                }
            }
        }
        
        let elapsed = String(format: "%.1f", Date().timeIntervalSince(scanStart) * 1000)
        GLLog.fsEvents.notice("proactiveScan: \(results.count) found, \(elapsed)ms, quarantined=\(l1Count), dirs=\(dirs.count), L2cache=\(self.safeCacheCount)")
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
        
        // §3.5: 维护 recentCandidates（所有有 FS 活动的 .app 路径，供 fallback scan 使用）
        let now = Date()
        recentCandidates[appPath] = now
        // 清理过期候选
        recentCandidates = recentCandidates.filter { now.timeIntervalSince($0.value) < candidateWindow }
        
        // 内部去重（3 秒窗口）
        if let lastSeen = recentPaths[appPath], now.timeIntervalSince(lastSeen) < deduplicationWindow {
            let elapsed = String(format: "%.1f", now.timeIntervalSince(lastSeen))
            GLLog.fsEvents.debug("FSEvents dedup: skipped \(appPath) (\(elapsed)s < 3s window)")
            return
        }
        recentPaths[appPath] = now
        
        // 清理过期记录
        recentPaths = recentPaths.filter { now.timeIntervalSince($0.value) < deduplicationWindow }
        
        // §3.1 P1: quarantine 预过滤（排除无 quarantine 的 app，getxattr 纳秒级不阻塞）
        guard Self.hasQuarantine(at: appPath) else {
            GLLog.fsEvents.debug("Quarantine check: \(appPath), hasQuarantine=false, skipped")
            // 文件可能被移到了 Trash，通知上层 reconcile
            onDirectoryChange?()
            return
        }
        
        // §3.2: spctl --assess 二次确认（异步执行，避免阻塞主线程 ~3 秒）
        let assessor = self.assessor
        let onDetection = self.onDetection
        DispatchQueue.global(qos: .userInitiated).async {
            let gkResult = assessor.assess(appPath: appPath)
            guard gkResult == .rejected else {
                let appName = URL(fileURLWithPath: appPath).lastPathComponent
                GLLog.fsEvents.info("FSEvents detected + assess: \(appName), result=\(String(describing: gkResult)), not blocked")
                return
            }
            
            let appURL = URL(fileURLWithPath: appPath)
            let bundleId = Bundle(url: appURL)?.bundleIdentifier
            GLLog.fsEvents.info("FSEvents detected + assess: \(appURL.lastPathComponent), result=rejected, bundleId=\(bundleId ?? "nil")")
            
            let event = DetectionEvent(
                source: .fsEvents,
                appPath: appURL,
                bundleId: bundleId,
                timestamp: now
            )
            onDetection?(event)
        }
    }
    
    private func extractAppPath(from path: String) -> String? {
        guard let range = path.range(of: ".app") else { return nil }
        return String(path[path.startIndex..<range.upperBound])
    }
    
    // MARK: - Level 1 动态追加（§6.2）
    
    /// 动态追加监控目录（Level 1 升级时调用）
    func addDirectories(_ newDirs: [URL]) {
        let currentDirs = currentMonitoredDirectories
        let dirsToAdd = newDirs.filter { newDir in
            !currentDirs.contains(where: { $0.path == newDir.path })
        }
        guard !dirsToAdd.isEmpty else {
            GLLog.fsEvents.debug("addDirectories: all directories already monitored")
            return
        }
        
        stopWatching()
        let allDirs = currentDirs + dirsToAdd
        startWatching(directories: allDirs)
        GLLog.fsEvents.notice("Directories upgraded: \(allDirs.map(\.path))")
    }
    
    /// TCC 权限探测：尝试枚举目录内容判断是否有读取权限
    static func canAccessDirectory(_ url: URL) -> Bool {
        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil
            )
            return true
        } catch {
            return false
        }
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
