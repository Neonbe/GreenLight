import SwiftUI

/// §r06 确认态面板：安全扫描过渡 Loading 状态
/// 蓝白色调 + 静态盾牌图标 + 文字旁小旋转指示器
struct DetectionConfirmingView: View {
    let foundCount: Int
    
    // 入场动画状态
    @State private var panelOpacity: Double = 0
    @State private var panelOffset: CGFloat = -8
    @State private var panelScale: CGFloat = 0.96
    @State private var shieldOpacity: Double = 0
    @State private var labelOpacity: Double = 0
    @State private var messageOpacity: Double = 0
    @State private var subMessageOpacity: Double = 0
    
    // 旋转指示器
    @State private var spinnerRotation: Double = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - 色彩 Token
    
    private let bgColor = Color(red: 22/255, green: 28/255, blue: 45/255).opacity(0.95)
    private let glassBorder = Color.white.opacity(0.08)
    private let innerHighlight = Color.white.opacity(0.06)
    private let textSecondary = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.55)
    private let textMuted = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.35)
    private let scanBlue = Color(red: 100/255, green: 180/255, blue: 255/255)
    
    var body: some View {
        VStack(spacing: 20) {
            // 盾牌图标（静态主视觉）
            shieldIcon
                .opacity(shieldOpacity)
            
            // 状态标签 + 旋转指示器
            scanLabel
                .opacity(labelOpacity)
            
            // 说明文案
            VStack(spacing: 6) {
                Text("confirming.verifying")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(textSecondary)
                    .opacity(messageOpacity)
                
                Text("confirming.patience")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(textMuted)
                    .opacity(subMessageOpacity)
            }
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
        .onAppear { playEnterAnimation() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "confirming.accessibility"))
    }
    
    // MARK: - 盾牌图标（静态，柔和光晕）
    
    private var shieldIcon: some View {
        ZStack {
            // 背景光晕
            Circle()
                .fill(scanBlue.opacity(0.06))
                .frame(width: 56, height: 56)
                .blur(radius: 10)
            
            // 盾牌
            Image(systemName: "shield")
                .font(.system(size: 28, weight: .thin, design: .rounded))
                .foregroundColor(scanBlue.opacity(0.7))
        }
        .frame(width: 56, height: 56)
    }
    
    // MARK: - 标签 + 小旋转指示器
    
    private var scanLabel: some View {
        HStack(spacing: 6) {
            // 小旋转弧线（12px）
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    scanBlue.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(spinnerRotation))
            
            Text("confirming.title")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(scanBlue.opacity(0.9))
                .tracking(0.5)
        }
    }
    
    // MARK: - 入场动画
    
    private func playEnterAnimation() {
        if reduceMotion {
            panelOpacity = 1; panelOffset = 0; panelScale = 1
            shieldOpacity = 1; labelOpacity = 1
            messageOpacity = 1; subMessageOpacity = 1
            return
        }
        
        // Phase 1: 面板容器
        withAnimation(NDAnimation.panelTransition) {
            panelOpacity = 1; panelOffset = 0; panelScale = 1
        }
        
        // Phase 2: 盾牌入场
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(NDAnimation.cardEnter) { shieldOpacity = 1 }
        }
        
        // Phase 3: 标签 + 启动旋转
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(NDAnimation.cardEnter) { labelOpacity = 1 }
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                spinnerRotation = 360
            }
        }
        
        // Phase 4: 文案交错入场
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(NDAnimation.cardEnter) { messageOpacity = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(NDAnimation.cardEnter) { subMessageOpacity = 1 }
        }
    }
}
