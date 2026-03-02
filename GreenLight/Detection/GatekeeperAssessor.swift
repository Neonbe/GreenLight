import Foundation

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

/// 生产实现：调用 spctl --assess 判定 app 是否被 GK 拦截
struct GatekeeperAssessor: GatekeeperAssessing {
    func assess(appPath: String) -> GKAssessResult {
        let result = ShellExecutor.run("/usr/sbin/spctl",
            arguments: ["--assess", "--type", "exec", appPath])
        
        let gkResult: GKAssessResult
        switch result.exitCode {
        case 0:  gkResult = .accepted
        case 3:  gkResult = .rejected
        default: gkResult = .unknown
        }
        
        let appName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        GLLog.gkAssess.info("GK assess: \(appName), exitCode=\(result.exitCode), result=\(String(describing: gkResult))")
        
        return gkResult
    }
}

/// 测试用：可注入固定结果
struct FakeGatekeeperAssessor: GatekeeperAssessing {
    let result: GKAssessResult
    
    func assess(appPath: String) -> GKAssessResult {
        return result
    }
}
