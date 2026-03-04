import Foundation

/// §r07: 实验明文日志备份
/// 将关键事件同步写入 /tmp/greenlight_r07.log，绕过 os_log 脱敏
enum ExperimentLogger {
    private static let logFile = "/tmp/greenlight_r07.log"
    private static let queue = DispatchQueue(label: "com.greenlight.experiment.log")
    
    /// 写入一行明文日志（线程安全）
    static func log(_ message: String) {
        queue.async {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let ts = formatter.string(from: Date())
            let line = "[\(ts)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            
            if FileManager.default.fileExists(atPath: logFile) {
                if let handle = FileHandle(forWritingAtPath: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
    }
}
