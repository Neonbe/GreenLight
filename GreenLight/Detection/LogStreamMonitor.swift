import Foundation

/// GK 事件记录（用于时间线分析）
struct GKEventRecord {
    enum Category: String {
        case scan = "scan"
        case evaluate = "evaluate"
        case prompt = "prompt"
        case unrecognized = "other"
    }
    let timestamp: Date
    let category: Category
    let intervalMs: Int  // 距上一个 GK 事件的间隔（ms），首个为 -1
}

/// Channel A: 监听 syspolicyd 进程日志，实时捕获 Gatekeeper 拦截事件
class LogStreamMonitor: ObservableObject {
    private var process: Process?
    private var outputPipe: Pipe?
    @Published var isRunning = false
    
    /// 检测到事件时的回调
    var onDetection: ((DetectionEvent) -> Void)?
    
    /// GK 活动但无法提取路径时的回调（用于触发兜底扫描）
    var onGKActivity: (() -> Void)?
    
    // MARK: - GK 事件时间线（§r04 实验）
    
    /// 最近 60s 的 GK 事件记录（供 FSEvents 关联查询）
    private(set) var recentGKEvents: [GKEventRecord] = []
    private var lastGKEventTime: Date?
    private let gkEventWindow: TimeInterval = 60
    
    // MARK: - 正则（基于实验 A 真实日志）
    
    // 精确 Pattern: "GK Xprotect results:.*file://(.+\.app/)"
    static let xprotectPattern = try! NSRegularExpression(
        pattern: #"file://(/.+?\.app/)"#,
        options: []
    )
    
    // bundle_id Pattern: "bundle_id: (.+)\)"
    static let bundleIdPattern = try! NSRegularExpression(
        pattern: #"bundle_id:\s*([^\s\)]+)"#,
        options: []
    )
    
    // 看门狗参数
    private var retryCount = 0
    private let maxRetryDelay: TimeInterval = 30
    
    // 心跳计数器（§3.2）
    private var totalLines = 0
    private var gkHitCount = 0
    private var detectionCount = 0
    private var heartbeatTimer: Timer?
    private var startTime = Date()
    
    // MARK: - 启停
    
    func startMonitoring() {
        guard !isRunning else { return }
        launchProcess()
    }
    
    func stopMonitoring() {
        process?.terminate()
        process = nil
        isRunning = false
        retryCount = 0
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func launchProcess() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        proc.arguments = [
            "stream",
            "--predicate", #"process == "syspolicyd""#,
            "--style", "compact"
        ]
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        
        // 异步读取管道输出（避免阻塞）
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty {
                self?.totalLines += 1
                if let event = self?.parseLogLine(line) {
                    self?.detectionCount += 1
                    self?.onDetection?(event)
                }
            }
        }
        
        // 看门狗：子进程崩溃自动重启（指数退避）
        proc.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async { self?.isRunning = false }
            let status = proc.terminationStatus
            guard let self = self else { return }
            self.retryCount += 1
            let delay = min(pow(2.0, Double(self.retryCount - 1)), self.maxRetryDelay)
            GLLog.logStream.error("log stream terminated (status=\(status)), retry #\(self.retryCount) in \(delay)s")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.launchProcess()
            }
        }
        
        do {
            try proc.run()
            process = proc
            outputPipe = pipe
            isRunning = true
            retryCount = 0
            startTime = Date()
            totalLines = 0
            gkHitCount = 0
            detectionCount = 0
            GLLog.logStream.notice("log stream process started, pid=\(proc.processIdentifier)")
            startHeartbeat()
        } catch {
            GLLog.logStream.fault("Failed to start log stream: \(error)")
            scheduleRestart()
        }
    }
    
    // MARK: - 心跳（§3.2）
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let uptime = Int(Date().timeIntervalSince(self.startTime))
            GLLog.logStream.debug("logStream heartbeat: alive \(uptime)s, lines=\(self.totalLines), gkHits=\(self.gkHitCount), detections=\(self.detectionCount)")
            
            // §r04: 输出最近 60s 的 GK 事件时间线
            if !self.recentGKEvents.isEmpty {
                let timeline = self.recentGKEvents.map { "\($0.category.rawValue)(\($0.intervalMs)ms)" }.joined(separator: " → ")
                GLLog.logStream.info("GK timeline (\(self.recentGKEvents.count) events): \(timeline, privacy: .public)")
                ExperimentLogger.log("GK_TIMELINE events=\(self.recentGKEvents.count) timeline=\(timeline)")
            }
        }
    }
    
    // MARK: - 日志解析
    
    func parseLogLine(_ line: String) -> DetectionEvent? {
        // 必须包含 Gatekeeper 相关关键词
        guard line.contains("GK") || line.contains("quarantine") || line.contains("Xprotect") else {
            return nil
        }
        
        // GK 行命中
        gkHitCount += 1
        GLLog.logStream.debug("GK line: \(line, privacy: .public)")
        
        // §r04: 清理过期事件
        let now = Date()
        recentGKEvents = recentGKEvents.filter { now.timeIntervalSince($0.timestamp) < gkEventWindow }
        
        // 提取 file:// URL 路径
        let lineRange = NSRange(line.startIndex..., in: line)
        if let pathMatch = Self.xprotectPattern.firstMatch(in: line, range: lineRange),
           let pathRange = Range(pathMatch.range(at: 1), in: line) {
            // 主信号：提取到 file:// 路径
            let rawPath = String(line[pathRange])
            let decodedPath = rawPath.removingPercentEncoding ?? rawPath
            let appURL = URL(fileURLWithPath: decodedPath)
            
            var bundleId: String?
            if let bundleMatch = Self.bundleIdPattern.firstMatch(in: line, range: lineRange),
               let bundleRange = Range(bundleMatch.range(at: 1), in: line) {
                bundleId = String(line[bundleRange])
            }
            
            GLLog.logStream.info("Detected: \(appURL.lastPathComponent, privacy: .public), bundleId=\(bundleId ?? "nil", privacy: .public)")
            
            return DetectionEvent(
                source: .logStream,
                appPath: appURL,
                bundleId: bundleId,
                timestamp: Date()
            )
        }
        
        // 无 file:// 路径的 GK 行 → 按子类型分类日志 + 记录时间线
        let category: GKEventRecord.Category
        if line.contains("Prompt shown") {
            category = .prompt
            var bundleId: String? = "unknown"
            if let bundleMatch = Self.bundleIdPattern.firstMatch(in: line, range: lineRange),
               let bundleRange = Range(bundleMatch.range(at: 1), in: line) {
                bundleId = String(line[bundleRange])
            }
            GLLog.logStream.info("GK prompt shown, bundleId=\(bundleId ?? "unknown", privacy: .public)")
            onGKActivity?()
        } else if line.contains("performScan") {
            category = .scan
            GLLog.logStream.debug("GK scan initiated: \(String(line.prefix(120)), privacy: .public)")
        } else if line.contains("scan complete") {
            category = .scan
            GLLog.logStream.debug("GK scan completed: \(String(line.prefix(120)), privacy: .public)")
        } else if line.contains("evaluateScanResult") {
            category = .evaluate
            GLLog.logStream.debug("GK evaluate (no scan trigger): \(String(line.prefix(120)), privacy: .public)")
            onGKActivity?()  // §r05: evaluate 也触发主动扫描
        } else if line.contains("<private>") {
            category = .unrecognized
            GLLog.logStream.debug("GK line contains <private>, skipped: \(String(line.prefix(80)), privacy: .public)")
        } else {
            category = .unrecognized
            GLLog.logStream.debug("GK line unrecognized: \(String(line.prefix(120)), privacy: .public)")
        }
        
        // §r04: 记录 GK 事件到时间线
        let intervalMs: Int
        if let last = lastGKEventTime {
            intervalMs = Int(now.timeIntervalSince(last) * 1000)
        } else {
            intervalMs = -1
        }
        lastGKEventTime = now
        recentGKEvents.append(GKEventRecord(timestamp: now, category: category, intervalMs: intervalMs))
        GLLog.logStream.info("GK event: \(category.rawValue, privacy: .public), interval=\(intervalMs)ms, total_recent=\(self.recentGKEvents.count)")
        ExperimentLogger.log("GK_EVENT category=\(category.rawValue) interval=\(intervalMs)ms total=\(self.recentGKEvents.count)")
        
        return nil
    }
    
    // MARK: - 看门狗
    
    private func scheduleRestart() {
        retryCount += 1
        let delay = min(pow(2.0, Double(retryCount - 1)), maxRetryDelay)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.launchProcess()
        }
    }
}
