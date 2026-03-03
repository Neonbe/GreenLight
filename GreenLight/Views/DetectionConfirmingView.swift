import SwiftUI

/// §r06 确认态面板：GK 触发后、FSEvents 确认前的过渡 Loading 状态
/// 视觉 Token 严格复用 DetectionPanelView
struct DetectionConfirmingView: View {
    let foundCount: Int
    
    // 入场动画状态
    @State private var panelOpacity: Double = 0
    @State private var panelOffset: CGFloat = -8
    @State private var panelScale: CGFloat = 0.96
    @State private var statusOpacity: Double = 0
    @State private var dotsOpacity: Double = 0
    @State private var messageOpacity: Double = 0
    @State private var dotPulsing = [false, false, false]
    
    // 倒计时（5s 超时兜底）
    @State private var countdown: TimeInterval = 5.0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - 色彩 Token（复用 DetectionPanelView）
    
    private let bgColor = Color(red: 22/255, green: 28/255, blue: 45/255).opacity(0.95)
    private let glassBorder = Color.white.opacity(0.08)
    private let innerHighlight = Color.white.opacity(0.06)
    private let textSecondary = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.45)
    private let textMuted = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.25)
    private let amberColor = Color(red: 245/255, green: 158/255, blue: 11/255)
    
    var body: some View {
        VStack(spacing: 16) {
            // 状态指示灯
            statusIndicator
                .opacity(statusOpacity)
            
            // 三点呼吸动画
            dotsIndicator
                .opacity(dotsOpacity)
            
            // 文案
            messageSection
                .opacity(messageOpacity)
            
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
        .onAppear { playEnterAnimation() }
        .onReceive(timer) { _ in
            countdown -= 0.1
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Checking blocked applications")
    }
    
    // MARK: - 状态指示灯
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(amberColor)
                .frame(width: 8, height: 8)
                .shadow(color: amberColor.opacity(0.6), radius: 4)
                .modifier(AmberPulseModifier(reduceMotion: reduceMotion))
            
            Text("Checking...")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - 三点呼吸
    
    private var dotsIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(amberColor.opacity(dotPulsing[i] ? 1.0 : 0.3))
                    .frame(width: 6, height: 6)
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: dotPulsing[i]
                    )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 文案
    
    private var messageSection: some View {
        VStack(spacing: 4) {
            Text("Verifying a blocked app.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textSecondary)
            
            Text("This only takes a moment.")
                .font(.system(size: 11))
                .foregroundColor(textMuted)
        }
    }
    
    // MARK: - 倒计时进度条
    
    private var countdownBar: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 1)
                .fill(amberColor.opacity(0.5))
                .frame(width: geo.size.width * max(0, countdown / 5.0), height: 2)
                .animation(reduceMotion ? .none : .linear(duration: 0.1), value: countdown)
        }
        .frame(height: 2)
    }
    
    // MARK: - 入场动画（复用 NDAnimation）
    
    private func playEnterAnimation() {
        if reduceMotion {
            panelOpacity = 1; panelOffset = 0; panelScale = 1
            statusOpacity = 1; dotsOpacity = 1; messageOpacity = 1
            dotPulsing = [true, true, true]
            return
        }
        
        // Phase 1: 面板容器
        withAnimation(NDAnimation.panelTransition) {
            panelOpacity = 1; panelOffset = 0; panelScale = 1
        }
        
        // Phase 2: 内容交错入场
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(NDAnimation.cardEnter) { statusOpacity = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(NDAnimation.cardEnter) { dotsOpacity = 1 }
            // 启动三点呼吸
            for i in 0..<3 { dotPulsing[i] = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(NDAnimation.cardEnter) { messageOpacity = 1 }
        }
    }
}

// MARK: - 琥珀色脉冲（复用 DetectionPanelView.PulseModifier 模式）

private struct AmberPulseModifier: ViewModifier {
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
