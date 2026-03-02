import Foundation

/// 检测层的原始事件
struct DetectionEvent {
    let source: Source
    let appPath: URL
    let bundleId: String?
    let timestamp: Date
    
    enum Source: Hashable {
        case logStream   // Channel A：syspolicyd 直接路径匹配（最高置信）
        case fsEvents    // Channel B：FSEvents 实时文件变动（高置信）
        case scan        // Fallback：批量扫描结果（低置信）
    }
}

/// 去重后的最终事件
struct GreenLightEvent {
    let appPath: URL
    let appName: String
    let bundleId: String?
    let sources: Set<DetectionEvent.Source>
    let timestamp: Date
}
