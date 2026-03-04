import SwiftUI
import AppKit

/// 检测浮动面板 — 结果态视图
/// 展示被拦截应用信息，提供忽略/修复并打开两个操作
struct DetectionPanelView: View {
    let event: GreenLightEvent
    let onDismiss: () -> Void
    let onFix: (Bool) -> Void  // Bool = shouldOpen
    
    @State private var countdown: TimeInterval = 15.0
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
    
    // 按钮 hover 状态
    @State private var isDismissHovered = false
    @State private var isFixHovered = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    enum FixState { case idle, fixing, success, failure }
    
    // MARK: - 色彩 Token
    
    private let bgColor = Color(red: 22/255, green: 28/255, blue: 45/255).opacity(0.95)
    private let glassBorder = Color.white.opacity(0.08)
    private let innerHighlight = Color.white.opacity(0.06)
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let textSecondary = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.55)
    private let textMuted = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.30)
    private let warmAmber = Color(red: 245/255, green: 180/255, blue: 80/255)
    private let actionBlue = Color(red: 55/255, green: 135/255, blue: 250/255)
    private let redColor = Color(red: 239/255, green: 68/255, blue: 68/255)
    
    private let maxCountdown: TimeInterval = 15.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            statusIndicator
                .opacity(statusOpacity)
            
            appInfoSection
                .opacity(appInfoOpacity)
                .offset(x: appInfoOffset)
            
            buttonSection
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
        }
        .padding(24)
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
        .accessibilityLabel(String(localized: "detection.accessibility.needsConfirmation \(event.appName)"))
    }
    
    // MARK: - 状态指示
    
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(warmAmber)
            
            Text("detection.securityCheck")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - App 信息区
    
    private var appInfoSection: some View {
        HStack(spacing: 14) {
            appIcon
                .frame(width: 48, height: 48)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(event.appName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                
                Text(event.appPath.path)
                    .font(.system(size: 11, design: .rounded))
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
        HStack(spacing: 10) {
            if fixState == .failure {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage ?? String(localized: "detection.fixFailed"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(redColor)
                    
                    dismissActionButton(title: String(localized: "detection.close"), showCountdown: false)
                }
            } else {
                dismissActionButton(title: String(localized: "detection.dismiss"), showCountdown: timerActive)
                    .accessibilityHint(String(localized: "detection.accessibility.dismissHint"))
                
                Spacer()
                
                fixAndOpenButton
                    .accessibilityHint(String(localized: "detection.accessibility.fixHint"))
            }
        }
    }
    
    // MARK: - 忽略按钮（边框倒计时描边 + 秒数）
    
    private func dismissActionButton(title: String, showCountdown: Bool) -> some View {
        Button(action: {
            cancelTimer()
            onDismiss()
        }) {
            HStack(spacing: 0) {
                Text(title)
                if showCountdown {
                    Text(" (\(Int(ceil(countdown))))")
                        .monospacedDigit()
                }
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                ZStack {
                    // 填充背景
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                    
                    if showCountdown {
                        // 底层轨道边框
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.04), lineWidth: 1.5)
                        
                        // 倒计时描边进度
                        RoundedRectangle(cornerRadius: 10)
                            .trim(from: 0, to: max(0, countdown / maxCountdown))
                            .stroke(
                                Color.white.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .animation(reduceMotion ? .none : NDAnimation.countdownTick, value: countdown)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .onHover { isDismissHovered = $0 }
        .scaleEffect(isDismissHovered ? 1.03 : 1.0)
        .brightness(isDismissHovered ? 0.06 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.86), value: isDismissHovered)
    }
    
    // MARK: - 修复并打开按钮（蓝色）
    
    private var fixAndOpenButton: some View {
        Button(action: {
            cancelTimer()
            performFix(shouldOpen: true)
        }) {
            Text(fixState == .success ? "✓" : String(localized: "detection.fixAndOpen"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(actionBlue)
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .disabled(fixState == .fixing || fixState == .success)
        .onHover { isFixHovered = $0 }
        .scaleEffect(isFixHovered ? 1.03 : 1.0)
        .brightness(isFixHovered ? 0.08 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.86), value: isFixHovered)
    }
    
    // MARK: - 动作
    
    private func performFix(shouldOpen: Bool) {
        fixState = .fixing
        onFix(shouldOpen)
    }
    
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
            panelOpacity = 1; panelOffset = 0; panelScale = 1
            statusOpacity = 1
            appInfoOpacity = 1; appInfoOffset = 0
            buttonOpacity = 1; buttonOffset = 0
            return
        }
        
        withAnimation(NDAnimation.panelTransition) {
            panelOpacity = 1; panelOffset = 0; panelScale = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(NDAnimation.cardEnter) { statusOpacity = 1 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(NDAnimation.cardEnter) {
                appInfoOpacity = 1; appInfoOffset = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(NDAnimation.cardEnter) {
                buttonOpacity = 1; buttonOffset = 0
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
