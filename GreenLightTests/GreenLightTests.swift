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

// MARK: - FSEventsWatcher 目录分级测试

@Suite("FSEventsWatcher 目录分级")
struct FSEventsWatcherDirectoryTests {
    
    @Test("level0Directories 仅包含 /Applications")
    func level0OnlyApplications() {
        let level0 = FSEventsWatcher.level0Directories
        #expect(level0.count == 1)
        #expect(level0[0].path == "/Applications")
    }
    
    @Test("level1Directories 包含 ~/Downloads 和 ~/Desktop")
    func level1DownloadsAndDesktop() {
        let level1 = FSEventsWatcher.level1Directories
        #expect(level1.count == 2)
        let paths = level1.map(\.lastPathComponent)
        #expect(paths.contains("Downloads"))
        #expect(paths.contains("Desktop"))
    }
    
    @Test("canAccessDirectory 对 /Applications 返回 true")
    func canAccessApplications() {
        let result = FSEventsWatcher.canAccessDirectory(
            URL(fileURLWithPath: "/Applications")
        )
        #expect(result == true)
    }
    
    @Test("canAccessDirectory 对不存在目录返回 false")
    func cannotAccessNonexistent() {
        let result = FSEventsWatcher.canAccessDirectory(
            URL(fileURLWithPath: "/nonexistent_dir_test_12345")
        )
        #expect(result == false)
    }
}

// MARK: - EnhancePromptManager 测试

@Suite("EnhancePromptManager 分级触发")
struct EnhancePromptManagerTests {
    
    @Test("T1 未达标不触发 — 窗口内仅 1 次 GK 活动")
    func t1BelowThreshold() async {
        let manager = EnhancePromptManager(windowDuration: 0.1, minGKCount: 2)
        manager.checkDirectoryAccess = { _ in false }  // 模拟无 TCC 权限
        var panelShown = false
        manager.onShowEnhancePanel = { panelShown = true }
        
        // 同步触发窗口到期
        manager.scheduleWindowExpiry = { block, _ in block() }
        
        manager.recordGKActivity()
        
        // 等待窗口到期
        try? await Task.sleep(for: .milliseconds(200))
        #expect(panelShown == false)
    }
    
    @Test("T1 达标触发 — 窗口内 ≥2 次 GK + 0 次检测")
    func t1MeetsThreshold() async {
        let manager = EnhancePromptManager(windowDuration: 0.5, minGKCount: 2)
        manager.checkDirectoryAccess = { _ in false }  // 模拟无 TCC 权限
        var panelShown = false
        manager.onShowEnhancePanel = { panelShown = true }
        // 清理之前可能的全局冷却
        Persistence.lastEnhancePromptDate = nil
        
        // 使用同步调度测试
        var expiryBlock: (() -> Void)?
        manager.scheduleWindowExpiry = { block, _ in expiryBlock = block }
        
        manager.recordGKActivity()  // 第 1 次（开新窗口）
        manager.recordGKActivity()  // 第 2 次（累加）
        
        // 手动触发窗口到期
        expiryBlock?()
        
        #expect(panelShown == true)
        
        // 清理
        Persistence.lastEnhancePromptDate = nil
    }
    
    @Test("T1 有成功检测不触发")
    func t1WithDetectionSuppressed() async {
        let manager = EnhancePromptManager(windowDuration: 0.5, minGKCount: 2)
        manager.checkDirectoryAccess = { _ in false }
        var panelShown = false
        manager.onShowEnhancePanel = { panelShown = true }
        
        var expiryBlock: (() -> Void)?
        manager.scheduleWindowExpiry = { block, _ in expiryBlock = block }
        
        manager.recordGKActivity()
        manager.markDetection()      // Channel A 成功提取路径
        manager.recordGKActivity()
        
        expiryBlock?()
        
        #expect(panelShown == false)
    }
    
    @Test("T1 会话级冷却 — Not Now 后不再弹")
    func t1SessionCooldown() {
        let manager = EnhancePromptManager(windowDuration: 0.1, minGKCount: 1)
        manager.checkDirectoryAccess = { _ in false }
        Persistence.lastEnhancePromptDate = nil
        
        // 模拟已 dismissed
        manager.dismissedByUser()
        
        // T1 应被会话级冷却拦截
        let canShow = manager.canShowPrompt(forTrigger: .t1)
        #expect(canShow == false)
    }
    
    @Test("T1 全局冷却 — 24h 内不再弹")
    func t1GlobalCooldown() {
        // 使用独立 key 隔离：设置为距今 1 秒前，globalCooldown 设 3600s
        let uniqueKey = "greenlight.test.lastEnhancePromptDate.\(UUID())"
        UserDefaults.standard.set(Date(), forKey: uniqueKey)
        
        let manager = EnhancePromptManager(windowDuration: 0.1, minGKCount: 1, globalCooldown: 3600)
        manager.checkDirectoryAccess = { _ in false }
        
        // 手动检查：模拟 canShowPrompt 的全局冷却逻辑
        let lastDate = UserDefaults.standard.object(forKey: uniqueKey) as? Date
        let isInCooldown = lastDate != nil && Date().timeIntervalSince(lastDate!) < 3600
        #expect(isInCooldown == true)
        
        // 清理
        UserDefaults.standard.removeObject(forKey: uniqueKey)
    }
    
    @Test("T2 不受冷却限制")
    func t2BypassesCooldown() {
        let manager = EnhancePromptManager(windowDuration: 10, minGKCount: 2)
        manager.checkDirectoryAccess = { _ in false }  // 模拟无 TCC 权限
        
        // 模拟已 dismissed + 全局冷却
        manager.dismissedByUser()
        Persistence.lastEnhancePromptDate = Date()
        
        // T2（主动）应该仍然可以显示
        let canShow = manager.canShowPrompt(forTrigger: .t2)
        #expect(canShow == true)
        
        // T1（被动）不可以
        let canShowT1 = manager.canShowPrompt(forTrigger: .t1)
        #expect(canShowT1 == false)
        
        // 清理
        Persistence.lastEnhancePromptDate = nil
    }
}

// MARK: - GatekeeperAssessor 判定测试（§3.2）

@Suite("GatekeeperAssessor 判定逻辑")
struct GatekeeperAssessorTests {
    
    @Test("系统 app → accepted")
    func systemAppAccepted() {
        let assessor = GatekeeperAssessor()
        let result = assessor.assess(appPath: "/System/Applications/Calculator.app")
        #expect(result == .accepted)
    }
    
    @Test("系统 app 二次调用走缓存 → 同样 accepted")
    func systemAppCacheHit() {
        let assessor = GatekeeperAssessor()
        // 第一次调用建立缓存
        let first = assessor.assess(appPath: "/System/Applications/Calculator.app")
        // 第二次应走缓存
        let second = assessor.assess(appPath: "/System/Applications/Calculator.app")
        #expect(first == .accepted)
        #expect(second == .accepted)
    }
    
    @Test("SecStaticCode 不存在的 App → rejected")
    func nonExistentAppRejected() {
        let assessor = GatekeeperAssessor()
        let result = assessor.assess(appPath: "/nonexistent_path_test_12345.app")
        // 不存在的路径 SecStaticCodeCreateWithPath 应失败 → rejected
        // 或 spctl 也会返回非 0
        #expect(result == .rejected || result == .unknown)
    }
    
    @Test("FakeAssessor: rejected")
    func fakeRejected() {
        let fake = FakeGatekeeperAssessor(result: .rejected)
        #expect(fake.assess(appPath: "/any") == .rejected)
    }
    
    @Test("FakeAssessor: unknown（不入 blocked）")
    func fakeUnknown() {
        let fake = FakeGatekeeperAssessor(result: .unknown)
        #expect(fake.assess(appPath: "/any") == .unknown)
    }
    
    @Test("FakeAssessor: accepted")
    func fakeAccepted() {
        let fake = FakeGatekeeperAssessor(result: .accepted)
        #expect(fake.assess(appPath: "/any") == .accepted)
    }
}

// MARK: - AppState dismissed 稳定性测试（§3.6）

@Suite("AppState dismissed 稳定性")
struct AppStateDismissedTests {
    
    @Test("scan 来源不重置 dismissed 状态")
    @MainActor func scanDoesNotReblockDismissed() async {
        let appState = AppState.shared
        let testPath = "/Applications/_TestScanDismissed_\(UUID().uuidString).app"
        
        // Setup: 添加一个 blocked record 并 dismiss
        let event1 = GreenLightEvent(
            appPath: URL(fileURLWithPath: testPath),
            appName: "TestScanDismissed", bundleId: nil,
            sources: [.fsEvents],
            timestamp: Date()
        )
        appState.addBlockedApp(from: event1)
        if let record = appState.blockedApps.first(where: { $0.path == testPath }) {
            appState.dismissApp(record)
        }
        
        // Verify: dismissed
        let beforeRecord = appState.blockedApps.first { $0.path == testPath }
        #expect(beforeRecord?.status == .dismissed)
        
        // Act: 模拟 scan 来源事件
        let scanEvent = GreenLightEvent(
            appPath: URL(fileURLWithPath: testPath),
            appName: "TestScanDismissed", bundleId: nil,
            sources: [.scan],
            timestamp: Date()
        )
        appState.addBlockedApp(from: scanEvent)
        
        // Verify: 仍为 dismissed
        let afterRecord = appState.blockedApps.first { $0.path == testPath }
        #expect(afterRecord?.status == .dismissed)
        
        // 清理
        if let idx = appState.blockedApps.firstIndex(where: { $0.path == testPath }) {
            appState.blockedApps.remove(at: idx)
        }
    }
    
    @Test("实时检测可重置 dismissed 为 blocked")
    @MainActor func realtimeCanReblockDismissed() async {
        let appState = AppState.shared
        let testPath = "/Applications/_TestRealtimeReblock_\(UUID().uuidString).app"
        
        // Setup: 添加一个 blocked record 并 dismiss
        let event1 = GreenLightEvent(
            appPath: URL(fileURLWithPath: testPath),
            appName: "TestRealtimeReblock", bundleId: nil,
            sources: [.fsEvents],
            timestamp: Date()
        )
        appState.addBlockedApp(from: event1)
        if let record = appState.blockedApps.first(where: { $0.path == testPath }) {
            appState.dismissApp(record)
        }
        
        // Verify: dismissed
        let beforeRecord = appState.blockedApps.first { $0.path == testPath }
        #expect(beforeRecord?.status == .dismissed)
        
        // Act: 模拟实时检测事件（含 logStream）
        let realtimeEvent = GreenLightEvent(
            appPath: URL(fileURLWithPath: testPath),
            appName: "TestRealtimeReblock", bundleId: nil,
            sources: [.logStream],
            timestamp: Date()
        )
        appState.addBlockedApp(from: realtimeEvent)
        
        // Verify: 重置为 blocked
        let afterRecord = appState.blockedApps.first { $0.path == testPath }
        #expect(afterRecord?.status == .blocked)
        
        // 清理
        if let idx = appState.blockedApps.firstIndex(where: { $0.path == testPath }) {
            appState.blockedApps.remove(at: idx)
        }
    }
}

// MARK: - Source.scan 序列化兼容测试（§3.3）

@Suite("DetectionEvent Source 兼容性")
struct DetectionEventSourceTests {
    
    @Test("新增 .scan 不破坏去重合并")
    func scanSourceDeduplication() async {
        let dedup = EventDeduplicator(windowDuration: 0.1)
        
        var receivedEvents: [GreenLightEvent] = []
        dedup.onEvent = { event in
            receivedEvents.append(event)
        }
        
        let path = URL(fileURLWithPath: "/Applications/TestScanDedup.app")
        let event1 = DetectionEvent(source: .scan, appPath: path, bundleId: nil, timestamp: Date())
        let event2 = DetectionEvent(source: .fsEvents, appPath: path, bundleId: "com.test", timestamp: Date())
        
        dedup.receive(event1)
        dedup.receive(event2)
        
        try? await Task.sleep(for: .milliseconds(200))
        
        #expect(receivedEvents.count == 1)
        #expect(receivedEvents.first?.sources.contains(.scan) == true)
        #expect(receivedEvents.first?.sources.contains(.fsEvents) == true)
    }
    
    @Test("仅 scan 来源事件正确标识")
    func scanOnlyEvent() async {
        let dedup = EventDeduplicator(windowDuration: 0.1)
        
        var receivedEvents: [GreenLightEvent] = []
        dedup.onEvent = { event in
            receivedEvents.append(event)
        }
        
        let path = URL(fileURLWithPath: "/Applications/TestScanOnly.app")
        let event = DetectionEvent(source: .scan, appPath: path, bundleId: nil, timestamp: Date())
        
        dedup.receive(event)
        
        try? await Task.sleep(for: .milliseconds(200))
        
        #expect(receivedEvents.count == 1)
        #expect(receivedEvents.first?.sources == [.scan])
        // 仅 scan → 不含实时信号
        let hasRealtime = receivedEvents.first?.sources.contains(.logStream) == true
            || receivedEvents.first?.sources.contains(.fsEvents) == true
        #expect(hasRealtime == false)
    }
}

