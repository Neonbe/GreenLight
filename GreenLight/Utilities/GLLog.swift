import os

/// 全链路日志定义（§2.2）
/// 子系统 = Bundle ID，按模块分 Category
enum GLLog {
    static let subsystem = "com.greenlight.app"
    
    static let pipeline     = Logger(subsystem: subsystem, category: "pipeline")
    static let logStream    = Logger(subsystem: subsystem, category: "logStream")
    static let fsEvents     = Logger(subsystem: subsystem, category: "fsEvents")
    static let dedup        = Logger(subsystem: subsystem, category: "dedup")
    static let panel        = Logger(subsystem: subsystem, category: "panel")
    static let fix          = Logger(subsystem: subsystem, category: "fix")
    static let notification = Logger(subsystem: subsystem, category: "notification")
    static let state        = Logger(subsystem: subsystem, category: "state")
    static let onboarding   = Logger(subsystem: subsystem, category: "onboarding")
    static let enhance      = Logger(subsystem: subsystem, category: "enhance")
    static let gkAssess     = Logger(subsystem: subsystem, category: "gkAssess")
}
