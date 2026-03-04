import Foundation
import Security

/// spctl --assess 的三态判定结果
enum GKAssessResult: Equatable {
    case accepted    // 退出码 0：GK 通过
    case rejected    // 退出码 3：GK 拦截
    case unknown     // 退出码 1/2/其他：无法判定
}

/// 可注入依赖，便于测试
protocol GatekeeperAssessing {
    func assess(appPath: String) -> GKAssessResult
}

/// 生产实现：SecStaticCode 快速排除 + spctl 兜底 + 结果缓存（§3.3 + §3.4）
struct GatekeeperAssessor: GatekeeperAssessing {
    
    // MARK: - §3.4 结果缓存（内存字典，App 重启重建）
    
    /// 缓存 Key = 路径 + 修改时间
    private struct CacheKey: Hashable {
        let path: String
        let modDate: Date
    }
    
    /// 线程安全的缓存（spctl/SecStaticCode 在后台线程调用）
    private static let cacheQueue = DispatchQueue(label: "com.greenlight.gkassess.cache")
    private static var cache: [CacheKey: GKAssessResult] = [:]
    
    // MARK: - 主入口
    
    func assess(appPath: String) -> GKAssessResult {
        let appName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        
        // §3.4: 缓存检查（Key = 路径 + 修改时间）
        if let modDate = fileModificationDate(appPath) {
            let key = CacheKey(path: appPath, modDate: modDate)
            let cached = Self.cacheQueue.sync { Self.cache[key] }
            if let cached = cached {
                GLLog.gkAssess.info("GK assess (cached): \(appName, privacy: .public), result=\(String(describing: cached), privacy: .public)")
                return cached
            }
        }
        
        // §3.3: SecStaticCode 快速排除
        let quickResult = quickReject(appPath: appPath, appName: appName)
        if let quickResult = quickResult {
            GLLog.gkAssess.info("GK assess (SecStaticCode→rejected): \(appName, privacy: .public)")
            cacheResult(appPath: appPath, result: quickResult)
            return quickResult
        }
        
        // 签名正常 → spctl 兜底确认
        GLLog.gkAssess.info("GK assess: SecStaticCode passed for \(appName, privacy: .public), falling through to spctl")
        let result = ShellExecutor.run("/usr/sbin/spctl",
            arguments: ["--assess", "--type", "exec", appPath])
        
        let gkResult: GKAssessResult
        switch result.exitCode {
        case 0:  gkResult = .accepted   // GK 通过
        case 1:  gkResult = .rejected   // 签名损坏/资源缺失 → macOS 会阻止
        case 3:  gkResult = .rejected   // policy denied → GK 拦截
        default: gkResult = .unknown    // exitCode=2(参数错误)/-1(启动失败)/其他
        }
        
        GLLog.gkAssess.info("GK assess (spctl): \(appName, privacy: .public), exitCode=\(result.exitCode), result=\(String(describing: gkResult), privacy: .public)")
        ExperimentLogger.log("SPCTL_ASSESS app=\(appName) exitCode=\(result.exitCode) result=\(gkResult)")
        cacheResult(appPath: appPath, result: gkResult)
        return gkResult
    }
    
    // MARK: - §3.3 SecStaticCode 快速排除
    
    /// 快速检查签名有效性。返回值含义：
    /// - `.rejected`: 签名异常（损坏/不存在），直接判定拦截
    /// - `nil`: 签名正常，需要 spctl 兜底确认（可能未公证）
    private func quickReject(appPath: String, appName: String) -> GKAssessResult? {
        let url = URL(fileURLWithPath: appPath) as CFURL
        var codeRef: SecStaticCode?
        
        let createStatus = SecStaticCodeCreateWithPath(url, [], &codeRef)
        guard createStatus == errSecSuccess, let code = codeRef else {
            GLLog.gkAssess.notice("SecStaticCode CREATE failed: \(appName, privacy: .public), OSStatus=\(createStatus)")
            return .rejected  // 无法创建代码对象 → 视为异常
        }
        
        // §r07: 提取签名详情
        var signingInfo: CFDictionary?
        SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo)
        if let info = signingInfo as? [String: Any] {
            let identifier = info[kSecCodeInfoIdentifier as String] as? String ?? "nil"
            let teamId = info[kSecCodeInfoTeamIdentifier as String] as? String ?? "nil"
            let flags = info["flags"] as? UInt32 ?? 0
            GLLog.gkAssess.notice("SecStaticCode signingInfo: \(appName, privacy: .public), id=\(identifier, privacy: .public), team=\(teamId, privacy: .public), flags=\(flags)")
            ExperimentLogger.log("SIGNING_INFO app=\(appName) id=\(identifier) team=\(teamId) flags=\(flags)")
        }
        
        let checkStatus = SecStaticCodeCheckValidity(code, [], nil)
        if checkStatus != errSecSuccess {
            GLLog.gkAssess.notice("SecStaticCode VALIDITY failed: \(appName, privacy: .public), OSStatus=\(checkStatus)")
            ExperimentLogger.log("SECSTATICCODE_FAILED app=\(appName) OSStatus=\(checkStatus)")
            return .rejected  // 签名无效/损坏
        }
        
        // 签名正常，不能判定 → 需要 spctl 兜底
        GLLog.gkAssess.info("SecStaticCode passed: \(appName, privacy: .public), signature valid")
        return nil
    }
    
    // MARK: - 缓存写入
    
    private func cacheResult(appPath: String, result: GKAssessResult) {
        guard let modDate = fileModificationDate(appPath) else { return }
        let key = CacheKey(path: appPath, modDate: modDate)
        Self.cacheQueue.sync {
            Self.cache[key] = result
        }
    }
    
    private func fileModificationDate(_ path: String) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }
}

/// 测试用：可注入固定结果
struct FakeGatekeeperAssessor: GatekeeperAssessing {
    let result: GKAssessResult
    
    func assess(appPath: String) -> GKAssessResult {
        return result
    }
}
