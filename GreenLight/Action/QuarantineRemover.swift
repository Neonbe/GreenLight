import Foundation
import AppKit

/// 移除 quarantine 属性 + 可选自动打开
class QuarantineRemover {
    
    enum FixResult {
        case success
        case failure(RemovalError)
    }
    
    enum RemovalError: Error {
        case needsAdmin(message: String, command: String)
        case fileNotFound(String)
    }
    
    /// 移除 quarantine 属性
    func removeQuarantine(at appPath: URL) -> FixResult {
        // 检查文件存在
        guard FileManager.default.fileExists(atPath: appPath.path) else {
            return .failure(.fileNotFound("应用不存在: \(appPath.path)"))
        }
        
        // 如果本身没有 quarantine，直接成功
        guard FSEventsWatcher.hasQuarantine(at: appPath.path) else {
            return .success
        }
        
        // Step 1: 参数化执行（无 shell 解析，无注入风险）
        ShellExecutor.run("/usr/bin/xattr", arguments: ["-rd", "com.apple.quarantine", appPath.path])
        
        // Step 2: 验证（getxattr C API，不盲信退出码）
        if !FSEventsWatcher.hasQuarantine(at: appPath.path) {
            return .success
        }
        
        // Step 3: 失败提示（极少见，如 root-owned app）
        return .failure(.needsAdmin(
            message: "此应用需要管理员权限修复，请联系我们",
            command: "sudo xattr -rd com.apple.quarantine '\(appPath.path)'"
        ))
    }
    
    /// 自动打开应用
    func openApp(at path: URL) {
        NSWorkspace.shared.open(path)
    }
}
