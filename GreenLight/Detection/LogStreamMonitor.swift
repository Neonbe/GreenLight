import Foundation

/// Channel A: 监听 syspolicyd 进程日志，实时捕获 Gatekeeper 拦截事件
class LogStreamMonitor: ObservableObject {
    private var process: Process?
    private var outputPipe: Pipe?
    @Published var isRunning = false
    
    /// 检测到事件时的回调
    var onDetection: ((DetectionEvent) -> Void)?
    
    /// GK 活动但无法提取路径时的回调（用于触发兜底扫描）
    var onGKActivity: (() -> Void)?
    
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
        GLLog.logStream.debug("GK line: \(line)")
        
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
            
            GLLog.logStream.info("Detected: \(appURL.lastPathComponent), bundleId=\(bundleId ?? "nil")")
            
            return DetectionEvent(
                source: .logStream,
                appPath: appURL,
                bundleId: bundleId,
                timestamp: Date()
            )
        }
        
        // 无 file:// 路径的 GK 行 → 按子类型分类日志
        if line.contains("Prompt shown") {
            // 提取 bundleId（如果有）
            var bundleId: String? = "unknown"
            if let bundleMatch = Self.bundleIdPattern.firstMatch(in: line, range: lineRange),
               let bundleRange = Range(bundleMatch.range(at: 1), in: line) {
                bundleId = String(line[bundleRange])
            }
            GLLog.logStream.info("GK prompt shown, bundleId=\(bundleId ?? "unknown")")
            onGKActivity?()
        } else if line.contains("performScan") {
            GLLog.logStream.debug("GK scan initiated: \(String(line.prefix(120)))")
        } else if line.contains("scan complete") {
            GLLog.logStream.debug("GK scan completed: \(String(line.prefix(120)))")
        } else if line.contains("evaluateScanResult") {
            GLLog.logStream.debug("GK evaluate: \(String(line.prefix(120)))")
            onGKActivity?()
        } else if line.contains("<private>") {
            GLLog.logStream.debug("GK line contains <private>, cannot extract path: \(String(line.prefix(80)))")
            onGKActivity?()
        } else {
            GLLog.logStream.debug("GK line unrecognized: \(String(line.prefix(120)))")
        }
        
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
