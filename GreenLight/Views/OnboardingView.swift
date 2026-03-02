import SwiftUI
import ServiceManagement

// MARK: - Onboarding 主视图

/// Onboarding 引导流程（2 步：Brand → Trust）
struct OnboardingView: View {
    var onComplete: () -> Void = {}
    @State private var currentStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            
            // 微妙的中心光晕
            RadialGradient(
                colors: [Color.white.opacity(0.025), Color.clear],
                center: .center,
                startRadius: 60,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                ZStack {
                    if currentStep == 0 {
                        BrandStep(reduceMotion: reduceMotion) {
                            let anim: Animation = reduceMotion
                                ? .linear(duration: 0.15)
                                : .spring(response: 0.45, dampingFraction: 0.88)
                            withAnimation(anim) { currentStep = 1 }
                            GLLog.onboarding.info("Onboarding step: 2")
                        }
                        .transition(pageTransition)
                    } else {
                        TrustStep(reduceMotion: reduceMotion) {
                            GLLog.onboarding.notice("Onboarding completed")
                            Persistence.hasCompletedOnboarding = true
                            onComplete()
                        }
                        .transition(pageTransition)
                    }
                }
                
                Spacer()
                Spacer().frame(height: 48)
            }
        }
        .frame(width: 900, height: 620)
    }
    
    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .offset(x: 30).combined(with: .opacity).combined(with: .scale(scale: 0.98)),
                removal: .offset(x: -30).combined(with: .opacity).combined(with: .scale(scale: 0.98))
            )
    }
}

// MARK: - Step 1 · Brand

private struct BrandStep: View {
    let reduceMotion: Bool
    let onContinue: () -> Void
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            OBTrafficLight(reduceMotion: reduceMotion)
                .stagger(0, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 36)
            
            Text("G r e e n L i g h t")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(OB.textPrimary)
                .stagger(1, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 16)
            
            Text("Detects and unblocks your apps — instantly.")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(OB.textMuted)
                .stagger(2, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 48)
            
            Button("Continue", action: onContinue)
                .buttonStyle(OBButtonStyle(isPrimary: false))
                .stagger(3, appeared: appeared, reduceMotion: reduceMotion)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 2 · Trust

private struct TrustStep: View {
    let reduceMotion: Bool
    let onGetStarted: () -> Void
    @State private var appeared = false
    @State private var shieldVisible = false
    @State private var shieldBrightness: Double = 0
    @State private var launchAtLogin = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 盾牌
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(.linearGradient(
                    colors: [OB.textPrimary.opacity(0.8), OB.textPrimary.opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                ))
                .scaleEffect(shieldVisible ? 1 : 0.85)
                .offset(y: shieldVisible ? 0 : 10)
                .opacity(shieldVisible ? 1 : 0)
                .brightness(shieldBrightness)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.65),
                    value: shieldVisible
                )
            
            Spacer().frame(height: 32)
            
            Text("Your privacy, first.")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(OB.textPrimary)
                .stagger(1, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 12)
            
            Text("Runs offline · No data collected · Open source")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(OB.textMuted)
                .stagger(2, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 40)
            
            // Toggle 卡片
            OBToggleCard(isOn: $launchAtLogin)
                .frame(maxWidth: 320)
                .stagger(3, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 48)
            
            Button("Get Started") {
                setLoginItem(enabled: launchAtLogin)
                onGetStarted()
            }
            .buttonStyle(OBButtonStyle(isPrimary: true))
            .stagger(4, appeared: appeared, reduceMotion: reduceMotion)
        }
        .onAppear {
            appeared = true
            shieldVisible = true
            guard !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) { shieldBrightness = 0.12 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) { shieldBrightness = 0 }
                }
            }
        }
    }
    
    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            GLLog.onboarding.info("Login item set: \(enabled)")
        } catch {
            GLLog.onboarding.error("Login item failed: \(error)")
        }
    }
}

// MARK: - 拟物红绿灯

private struct OBTrafficLight: View {
    let reduceMotion: Bool
    @State private var redIntensity: Double = 0
    @State private var amberIntensity: Double = 0.08
    @State private var greenIntensity: Double = 0
    @State private var greenPulse: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // 金属外壳
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color(white: 0.28), Color(white: 0.15), Color(white: 0.12), Color(white: 0.18)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.38), Color(white: 0.12)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    // 顶部高光
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 6)
                            .padding(.top, 2)
                    }
                    .frame(width: 52, height: 120)
                
                VStack(spacing: 8) {
                    OBBulb(color: OB.red, intensity: redIntensity)
                    OBBulb(color: OB.amber, intensity: amberIntensity)
                    OBBulb(color: OB.green, intensity: greenIntensity, brightness: greenPulse)
                }
            }
            
            // 柱杆
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.25), Color(white: 0.12), Color(white: 0.2)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: 10, height: 12)
            
            // 底座
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [Color(white: 0.28), Color(white: 0.1)],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color(white: 0.3), lineWidth: 0.5)
                )
                .frame(width: 32, height: 8)
        }
        .onAppear { runSequence() }
    }
    
    private func runSequence() {
        if reduceMotion {
            redIntensity = 0.1
            greenIntensity = 1
            return
        }
        // Phase 1: 红灯亮起 (spring 物理，自然感)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            redIntensity = 1
        }
        // Phase 2: amber 过渡 (红灯渐灭，黄灯微亮)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                redIntensity = 0.15
                amberIntensity = 0.5
            }
        }
        // Phase 3: 绿灯亮起 (黄灭绿亮)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                amberIntensity = 0.08
                greenIntensity = 1
            }
            // 绿灯脉冲：微闪后恢复
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) { greenPulse = 0.1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeInOut(duration: 0.3)) { greenPulse = 0 }
                }
            }
        }
    }
}

// MARK: - 灯泡

private struct OBBulb: View {
    let color: Color
    let intensity: Double
    var brightness: Double = 0
    
    var body: some View {
        ZStack {
            // 光晕
            Circle()
                .fill(color.opacity(intensity * 0.3))
                .frame(width: 44, height: 44)
                .blur(radius: 10)
            
            // 球体
            Circle()
                .fill(RadialGradient(
                    colors: [
                        color.opacity(min(intensity + 0.15, 1)),
                        color.opacity(intensity * 0.65),
                        color.opacity(intensity * 0.2),
                    ],
                    center: UnitPoint(x: 0.38, y: 0.32),
                    startRadius: 2, endRadius: 16
                ))
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
            
            // 高光
            Circle()
                .fill(Color.white.opacity(intensity * 0.4))
                .frame(width: 7, height: 6)
                .offset(x: -5, y: -5)
                .blur(radius: 2)
        }
        .frame(width: 30, height: 30)
        .brightness(brightness)
    }
}



// MARK: - Toggle 卡片

private struct OBToggleCard: View {
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Launch at login")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(OB.textPrimary)
                Text("Stay protected around the clock.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(OB.textMuted)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(OB.green)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

// MARK: - 按钮

struct OBButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        OBButtonBody(configuration: configuration, isPrimary: isPrimary)
    }
}

private struct OBButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isPrimary: Bool
    @State private var isHovered = false
    
    var body: some View {
        configuration.label
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(isPrimary ? .white : OB.textPrimary.opacity(0.8))
            .padding(.horizontal, 32)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPrimary ? OB.green : Color.white.opacity(0.06))
                    .shadow(
                        color: isPrimary ? OB.green.opacity(isHovered ? 0.3 : 0.15) : .clear,
                        radius: isPrimary ? 16 : 0,
                        y: isPrimary ? 6 : 0
                    )
            )
            .brightness(isHovered ? (isPrimary ? 0.06 : 0.1) : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.25), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - 交错入场

private struct StaggerModifier: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.35, dampingFraction: 0.85).delay(Double(index) * 0.05),
                value: appeared
            )
    }
}

private extension View {
    func stagger(_ index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        modifier(StaggerModifier(index: index, appeared: appeared, reduceMotion: reduceMotion))
    }
}

// MARK: - Tokens

private enum OB {
    static let bg            = Color(red: 15/255, green: 23/255, blue: 42/255)
    static let textPrimary   = Color(red: 248/255, green: 250/255, blue: 252/255)
    static let textMuted     = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.4)
    static let green         = Color(red: 34/255,  green: 197/255, blue: 94/255)
    static let red           = Color(red: 239/255, green: 68/255,  blue: 68/255)
    static let amber         = Color(red: 245/255, green: 158/255, blue: 11/255)
}
