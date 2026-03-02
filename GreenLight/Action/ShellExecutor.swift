import Foundation

/// Process 封装，参数化执行（禁止 shell 字符串拼接）
enum ShellExecutor {
    
    struct Result {
        let exitCode: Int32
        let output: String
        let error: String
    }
    
    /// 参数化执行命令（无 shell 解析，无注入风险）
    @discardableResult
    static func run(_ executable: String, arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return Result(exitCode: -1, output: "", error: error.localizedDescription)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        return Result(
            exitCode: process.terminationStatus,
            output: String(data: outputData, encoding: .utf8) ?? "",
            error: String(data: errorData, encoding: .utf8) ?? ""
        )
    }
}
