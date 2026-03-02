import Foundation

/// Channel A: 监听 syspolicyd 进程日志，实时捕获 Gatekeeper 拦截事件
class LogStreamMonitor: ObservableObject {
    private var process: Process?
    private var outputPipe: Pipe?
    @Published var isRunning = false
    
    /// 检测到事件时的回调
    var onDetection: ((DetectionEvent) -> Void)?
    
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
                if let event = self?.parseLogLine(line) {
                    self?.onDetection?(event)
                }
            }
        }
        
        // 看门狗：子进程崩溃自动重启（指数退避）
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.isRunning = false }
            self?.scheduleRestart()
        }
        
        do {
            try proc.run()
            process = proc
            outputPipe = pipe
            isRunning = true
            retryCount = 0
        } catch {
            print("[LogStreamMonitor] 启动失败: \(error)")
            scheduleRestart()
        }
    }
    
    // MARK: - 日志解析
    
    func parseLogLine(_ line: String) -> DetectionEvent? {
        // 必须包含 Gatekeeper 相关关键词
        guard line.contains("GK") || line.contains("quarantine") || line.contains("Xprotect") else {
            return nil
        }
        
        // 提取 file:// URL 路径
        let lineRange = NSRange(line.startIndex..., in: line)
        guard let pathMatch = Self.xprotectPattern.firstMatch(in: line, range: lineRange),
              let pathRange = Range(pathMatch.range(at: 1), in: line) else {
            return nil
        }
        
        let rawPath = String(line[pathRange])
        // URL decode（处理空格 %20、Unicode 等）
        let decodedPath = rawPath.removingPercentEncoding ?? rawPath
        let appURL = URL(fileURLWithPath: decodedPath)
        
        // 尝试提取 bundle_id（可选）
        var bundleId: String?
        if let bundleMatch = Self.bundleIdPattern.firstMatch(in: line, range: lineRange),
           let bundleRange = Range(bundleMatch.range(at: 1), in: line) {
            bundleId = String(line[bundleRange])
        }
        
        return DetectionEvent(
            source: .logStream,
            appPath: appURL,
            bundleId: bundleId,
            timestamp: Date()
        )
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
