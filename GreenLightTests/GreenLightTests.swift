import Testing
import Foundation
@testable import GreenLight

// MARK: - LogStreamMonitor 解析测试

@Suite("LogStreamMonitor 日志解析")
struct LogStreamMonitorTests {
    
    let monitor = LogStreamMonitor()
    
    @Test("正常日志行 - 提取 file:// 路径和 bundle_id")
    func parseNormalLine() {
        let line = """
        syspolicyd: GK Xprotect results: ...,file:///Applications/Antigravity%20Tools.app/
        """
        let event = monitor.parseLogLine(line)
        #expect(event != nil)
        #expect(event?.appPath.path.contains("Antigravity Tools.app") == true)
        #expect(event?.source == .logStream)
    }
    
    @Test("含 bundle_id 的日志行")
    func parseBundleId() {
        let line = """
        syspolicyd: GK evaluateScanResult: ...(bundle_id: com.lbjlaq.antigravity-tools)
        """
        // 这行没有 file://，不会提取路径
        let event = monitor.parseLogLine(line)
        #expect(event == nil)
    }
    
    @Test("含 file:// 和 bundle_id 的完整日志行")
    func parseFullLine() {
        let line = """
        syspolicyd: GK Xprotect results: file:///Applications/Some%20App.app/ ...(bundle_id: com.example.app)
        """
        let event = monitor.parseLogLine(line)
        #expect(event != nil)
        #expect(event?.appPath.path.contains("Some App.app") == true)
        #expect(event?.bundleId == "com.example.app")
    }
    
    @Test("<private> 字段 - 跳过但不崩溃")
    func parsePrivateField() {
        let line = """
        syspolicyd: GK some operation: <private>
        """
        let event = monitor.parseLogLine(line)
        #expect(event == nil)
    }
    
    @Test("非 GK 日志行 - 返回 nil")
    func parseNonGKLine() {
        let line = "syspolicyd: Some other log message without GK keywords"
        let event = monitor.parseLogLine(line)
        #expect(event == nil)
    }
    
    @Test("路径含空格和 Unicode")
    func parseUnicodePath() {
        let line = """
        syspolicyd: GK Xprotect results: file:///Users/user/Downloads/%E6%B5%8B%E8%AF%95%E5%BA%94%E7%94%A8.app/
        """
        let event = monitor.parseLogLine(line)
        #expect(event != nil)
        #expect(event?.appPath.path.contains("测试应用.app") == true)
    }
}

// MARK: - EventDeduplicator 测试

@Suite("EventDeduplicator 去重逻辑")
struct EventDeduplicatorTests {
    
    @Test("3s 内同路径双通道事件 - 合并为一个 GreenLightEvent")
    func deduplicateSamePath() async {
        let dedup = EventDeduplicator(windowDuration: 0.1) // 缩短窗口便于测试
        
        var receivedEvents: [GreenLightEvent] = []
        dedup.onEvent = { event in
            receivedEvents.append(event)
        }
        
        let path = URL(fileURLWithPath: "/Applications/TestApp.app")
        let event1 = DetectionEvent(source: .logStream, appPath: path, bundleId: "com.test", timestamp: Date())
        let event2 = DetectionEvent(source: .fsEvents, appPath: path, bundleId: nil, timestamp: Date())
        
        dedup.receive(event1)
        dedup.receive(event2)
        
        // 等待窗口过期
        try? await Task.sleep(for: .milliseconds(200))
        
        #expect(receivedEvents.count == 1)
        #expect(receivedEvents.first?.sources.contains(.logStream) == true)
        #expect(receivedEvents.first?.sources.contains(.fsEvents) == true)
        #expect(receivedEvents.first?.bundleId == "com.test") // 保留了 logStream 的 bundleId
    }
    
    @Test("不同路径事件 - 各自独立")
    func differentPaths() async {
        let dedup = EventDeduplicator(windowDuration: 0.1)
        
        var receivedEvents: [GreenLightEvent] = []
        dedup.onEvent = { event in
            receivedEvents.append(event)
        }
        
        let path1 = URL(fileURLWithPath: "/Applications/App1.app")
        let path2 = URL(fileURLWithPath: "/Applications/App2.app")
        
        dedup.receive(DetectionEvent(source: .logStream, appPath: path1, bundleId: nil, timestamp: Date()))
        dedup.receive(DetectionEvent(source: .logStream, appPath: path2, bundleId: nil, timestamp: Date()))
        
        try? await Task.sleep(for: .milliseconds(200))
        
        #expect(receivedEvents.count == 2)
    }
}

// MARK: - AppRecord 序列化测试

@Suite("AppRecord 数据持久化")
struct AppRecordTests {
    
    @Test("正反序列化")
    func encodeDecode() throws {
        let record = AppRecord(
            path: "/Applications/Test.app",
            bundleId: "com.test.app",
            appName: "Test",
            status: .blocked
        )
        
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(AppRecord.self, from: data)
        
        #expect(decoded.path == record.path)
        #expect(decoded.bundleId == record.bundleId)
        #expect(decoded.appName == record.appName)
        #expect(decoded.status == .blocked)
        #expect(decoded.greenLightCount == 0)
    }
    
    @Test("所有状态值可序列化")
    func allStatusValues() throws {
        for status in [AppRecord.Status.pending, .blocked, .dismissed, .cleared] {
            let record = AppRecord(path: "/test", appName: "Test", status: status)
            let data = try JSONEncoder().encode(record)
            let decoded = try JSONDecoder().decode(AppRecord.self, from: data)
            #expect(decoded.status == status)
        }
    }
}

// MARK: - QuarantineRemover 测试

@Suite("QuarantineRemover 修复逻辑")
struct QuarantineRemoverTests {
    
    let remover = QuarantineRemover()
    
    @Test("不存在的路径 - 返回 failure")
    func nonExistentPath() {
        let result = remover.removeQuarantine(at: URL(fileURLWithPath: "/nonexistent/path/App.app"))
        if case .failure = result {
            // 预期失败
        } else {
            Issue.record("Expected failure for non-existent path")
        }
    }
    
    @Test("无 quarantine 的路径 - 直接 success")
    func noQuarantineApp() {
        // /Applications 本身不是 .app 但存在
        // 用一个系统自带 app 测试（无 quarantine 属性）
        let systemApp = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        if FileManager.default.fileExists(atPath: systemApp.path) {
            let result = remover.removeQuarantine(at: systemApp)
            if case .success = result {
                // 预期成功（无 quarantine 即直接返回 success）
            } else {
                Issue.record("Expected success for app without quarantine")
            }
        }
    }
    
    @Test("hasQuarantine 对系统 app 返回 false")
    func systemAppHasNoQuarantine() {
        let systemApp = "/System/Applications/Calculator.app"
        if FileManager.default.fileExists(atPath: systemApp) {
            #expect(FSEventsWatcher.hasQuarantine(at: systemApp) == false)
        }
    }
}
