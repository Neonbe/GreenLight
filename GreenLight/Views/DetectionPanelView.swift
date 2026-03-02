import SwiftUI
import AppKit

/// 检测浮动面板的 SwiftUI 视图
/// PRD §3.1.1 — §3.1.3 严格实现
struct DetectionPanelView: View {
    let event: GreenLightEvent
    let onDismiss: () -> Void
    let onFix: (Bool) -> Void  // Bool = shouldOpen
    
    @State private var phase: PanelPhase = .entering
    @State private var contentTransition: ContentTransition = .idle
    @State private var countdown: TimeInterval = 10.0
    @State private var timerActive = true
    @State private var fixState: FixState = .idle
    @State private var shakeOffset: CGFloat = 0
    @State private var errorMessage: String?
    
    // 入场动画状态
    @State private var panelOpacity: Double = 0
    @State private var panelOffset: CGFloat = -8
    @State private var panelScale: CGFloat = 0.96
    @State private var statusOpacity: Double = 0
    @State private var appInfoOpacity: Double = 0
    @State private var appInfoOffset: CGFloat = -6
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 4
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    enum PanelPhase { case entering, visible, exiting }
    enum ContentTransition { case idle, exitingOld, enteringNew }
    enum FixState { case idle, fixing, success, failure }
    
    // MARK: - 色彩 Token（复用 ui_design_spec）
    
    private let bgColor = Color(red: 22/255, green: 28/255, blue: 45/255).opacity(0.95)
    private let glassBorder = Color.white.opacity(0.08)
    private let innerHighlight = Color.white.opacity(0.06)
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let textSecondary = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.45)
    private let textMuted = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.25)
    private let redColor = Color(red: 239/255, green: 68/255, blue: 68/255)
    private let greenColor = Color(red: 34/255, green: 197/255, blue: 94/255)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 状态指示灯
            statusIndicator
                .opacity(statusOpacity)
            
            // App 信息区
            appInfoSection
                .opacity(appInfoOpacity)
                .offset(x: appInfoOffset)
            
            // 按钮区
            buttonSection
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
            
            // 倒计时进度条
            countdownBar
        }
        .padding(20)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(glassBorder, lineWidth: 1)
        )
        // 内高光
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(innerHighlight)
                .frame(height: 1)
                .padding(.horizontal, 1)
                .padding(.top, 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 20)
        .opacity(panelOpacity)
        .offset(y: panelOffset)
        .scaleEffect(panelScale)
        .offset(x: shakeOffset)
        .modifier(SuccessPulseModifier(trigger: fixState == .success))
        .onReceive(timer) { _ in
            guard timerActive else { return }
            countdown -= 0.1
            if countdown <= 0 {
                timerActive = false
                dismissPanel()
            }
        }
        .onAppear {
            playEnterAnimation()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GreenLight 检测到 \(event.appName) 被拦截")
    }
    
    // MARK: - 状态指示灯
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(redColor)
                .frame(width: 8, height: 8)
                .shadow(color: redColor.opacity(0.6), radius: 4)
                .modifier(PulseModifier(reduceMotion: reduceMotion))
            
            Text("检测到拦截")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - App 信息区
    
    private var appInfoSection: some View {
        HStack(spacing: 12) {
            // App 图标
            appIcon
                .frame(width: 40, height: 40)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.appName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                
                Text(event.appPath.path)
                    .font(.system(size: 11))
                    .foregroundColor(textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
    
    @ViewBuilder
    private var appIcon: some View {
        let nsImage = NSWorkspace.shared.icon(forFile: event.appPath.path)
        Image(nsImage: nsImage)
            .resizable()
            .interpolation(.high)
    }
    
    // MARK: - 按钮区
    
    private var buttonSection: some View {
        HStack(spacing: 8) {
            if fixState == .failure {
                // 错误状态：显示错误信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(errorMessage ?? "修复失败")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(redColor)
                    
                    HStack(spacing: 8) {
                        panelButton("关闭", style: .secondary) {
                            dismissPanel()
                        }
                    }
                }
            } else {
                // 忽略
                panelButton("忽略", style: .secondary) {
                    cancelTimer()
                    onDismiss()
                }
                .accessibilityHint("忽略此拦截事件")
                
                // 修复
                panelButton("修复", style: .tertiary) {
                    cancelTimer()
                    performFix(shouldOpen: false)
                }
                .accessibilityHint("修复此应用但不打开")
                
                // 修复并打开
                panelButton(
                    fixState == .success ? "✓" : "修复并打开",
                    style: .primary
                ) {
                    cancelTimer()
                    performFix(shouldOpen: true)
                }
                .accessibilityHint("修复此应用并自动打开")
                .disabled(fixState == .fixing || fixState == .success)
            }
        }
    }
    
    // MARK: - 倒计时进度条
    
    private var countdownBar: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 1)
                .fill(countdown <= 3 ? redColor : textMuted)
                .frame(width: geo.size.width * max(0, countdown / 10.0), height: 2)
                .animation(reduceMotion ? .none : .linear(duration: 0.1), value: countdown)
        }
        .frame(height: 2)
        .opacity(timerActive ? 1 : 0)
    }
    
    // MARK: - 按钮组件
    
    enum ButtonStyleType { case primary, secondary, tertiary }
    
    private func panelButton(_ title: String, style: ButtonStyleType, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(buttonTextColor(for: style))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(buttonBgColor(for: style))
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .onHover { hovering in
            // hover brightness 通过 SwiftUI 的 .brightness modifier 实现
        }
    }
    
    private func buttonTextColor(for style: ButtonStyleType) -> Color {
        switch style {
        case .primary: return .white
        case .secondary: return textSecondary
        case .tertiary: return textPrimary
        }
    }
    
    private func buttonBgColor(for style: ButtonStyleType) -> Color {
        switch style {
        case .primary: return fixState == .success ? greenColor.opacity(1.1) : greenColor
        case .secondary: return Color.white.opacity(0.06)
        case .tertiary: return Color.white.opacity(0.08)
        }
    }
    
    // MARK: - 动作
    
    private func performFix(shouldOpen: Bool) {
        fixState = .fixing
        onFix(shouldOpen)
    }
    
    /// 外部调用：标记修复成功
    func markSuccess() {
        fixState = .success
    }
    
    private func cancelTimer() {
        timerActive = false
    }
    
    private func dismissPanel() {
        onDismiss()
    }
    
    // MARK: - 入场动画
    
    private func playEnterAnimation() {
        if reduceMotion {
            panelOpacity = 1
            panelOffset = 0
            panelScale = 1
            statusOpacity = 1
            appInfoOpacity = 1
            appInfoOffset = 0
            buttonOpacity = 1
            buttonOffset = 0
            return
        }
        
        // Phase 1: 面板容器
        withAnimation(NDAnimation.panelTransition) {
            panelOpacity = 1
            panelOffset = 0
            panelScale = 1
        }
        
        // Phase 2: 内容交错入场
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(NDAnimation.cardEnter) {
                statusOpacity = 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(NDAnimation.cardEnter) {
                appInfoOpacity = 1
                appInfoOffset = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(NDAnimation.cardEnter) {
                buttonOpacity = 1
                buttonOffset = 0
            }
        }
    }
}

// MARK: - 脉冲动画修饰器

private struct PulseModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (isPulsing ? 0.6 : 1.0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - 成功脉冲修饰器

private struct SuccessPulseModifier: ViewModifier {
    let trigger: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .brightness(isPulsing ? 0.05 : 0)
            .onChange(of: trigger) { newValue in
                guard newValue else { return }
                withAnimation(NDAnimation.successPulse) { isPulsing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(NDAnimation.successPulse) { isPulsing = false }
                }
            }
    }
}
