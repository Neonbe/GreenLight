import Foundation

/// 检测层的原始事件
struct DetectionEvent {
    let source: Source
    let appPath: URL
    let bundleId: String?
    let timestamp: Date
    
    enum Source: Hashable {
        case logStream
        case fsEvents
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
