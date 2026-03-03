import SwiftUI

/// 全局 Spring 动画预设，统一全 App 动画风格
/// 参考 Apple HIG Spring Physics
enum NDAnimation {
    // MARK: - 响应速度参数
    private static let snappy: Double = 0.25   // 快速响应（点击）
    private static let smooth: Double = 0.35   // 流畅过渡（面板展开）
    private static let gentle: Double = 0.5    // 柔和反馈（成功）
    
    // MARK: - 阻尼参数
    private static let critical: Double = 1.0  // 无弹跳
    private static let slight: Double = 0.85   // 轻微弹跳
    private static let bouncy: Double = 0.6    // 明显弹跳
    
    // MARK: - 动画预设
    
    /// 面板入场：从上方微滑入（response: 0.35, damping: 0.85）
    static var panelTransition: Animation { .spring(response: smooth, dampingFraction: slight) }
    
    /// 卡片/内容入场：弹跳进入（response: 0.25, damping: 0.6）
    static var cardEnter: Animation { .spring(response: snappy, dampingFraction: bouncy) }
    
    /// 卡片/内容退场：无弹跳干净退出（response: 0.25, damping: 1.0）
    static var cardExit: Animation { .spring(response: snappy, dampingFraction: critical) }
    
    /// 进度更新（response: 0.25, damping: 1.0）
    static var progressUpdate: Animation { .spring(response: snappy, dampingFraction: critical) }
    
    /// 修复成功脉冲（response: 0.5, damping: 0.6）
    static var successPulse: Animation { .spring(response: gentle, dampingFraction: bouncy) }
    
    /// 修复失败抖动（response: 0.1, damping: 0.2）
    static var errorShake: Animation { .spring(response: 0.1, dampingFraction: 0.2) }
    
    // MARK: - 扫描动画
    
    /// 扫描主弧旋转（线性无限循环，1.2s 一周）
    static var scanRotation: Animation { .linear(duration: 1.2).repeatForever(autoreverses: false) }
    
    /// 扫描副弧旋转（稍慢，1.8s 一周）
    static var scanRotationSlow: Animation { .linear(duration: 1.8).repeatForever(autoreverses: false) }
    
    /// 倒计时 tick（平滑更新）
    static var countdownTick: Animation { .linear(duration: 0.1) }
    
    // MARK: - 交错入场间隔
    static let staggerInterval: Double = 0.05  // 50ms
}
