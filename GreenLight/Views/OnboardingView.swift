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
            // 深邃背景 + 微妙径向渐变（中心稍亮，边缘暗沉）
            OB.bg.ignoresSafeArea()
            
            RadialGradient(
                colors: [Color.white.opacity(0.03), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 步骤指示器：距顶部留出大量空间（hiddenTitleBar 后红黄绿按钮在此区域）
                Spacer().frame(height: 48)
                
                OBStepIndicator(current: currentStep)
                
                Spacer()
                
                ZStack {
                    if currentStep == 0 {
                        BrandStep(reduceMotion: reduceMotion) {
                            let anim: Animation = reduceMotion
                                ? .linear(duration: 0.15)
                                : .spring(response: 0.4, dampingFraction: 0.85)
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
                Spacer().frame(height: 32)
            }
        }
        .frame(width: 780, height: 560)
    }
    
    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .offset(x: 30).combined(with: .opacity),
                removal: .offset(x: -30).combined(with: .opacity)
            )
    }
}

// MARK: - Step 1 · Brand（品牌认知）

private struct BrandStep: View {
    let reduceMotion: Bool
    let onContinue: () -> Void
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            OBTrafficLight(reduceMotion: reduceMotion)
                .stagger(0, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 28)
            
            Text("GreenLight")
                .font(.system(size: 24, weight: .bold))
                .tracking(5)
                .foregroundColor(OB.textPrimary)
                .stagger(1, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 16)
            
            Text("macOS blocks apps downloaded from the internet.\nGreenLight detects and unblocks them — instantly.")
                .font(.system(size: 15))
                .foregroundColor(OB.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .stagger(2, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 32)
            
            OBFeatureCard(items: [
                "Detects blocked apps automatically",
                "One-click fix, no Terminal needed",
                "Runs silently, protects continuously",
            ])
            .frame(maxWidth: 380)
            .stagger(3, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 36)
            
            Button("Continue", action: onContinue)
                .buttonStyle(OBButtonStyle(isPrimary: false))
                .stagger(4, appeared: appeared, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, 80)
        .onAppear { appeared = true }
    }
}

// MARK: - Step 2 · Trust（安全承诺）

private struct TrustStep: View {
    let reduceMotion: Bool
    let onGetStarted: () -> Void
    @State private var appeared = false
    @State private var shieldVisible = false
    @State private var shieldBrightness: Double = 0
    @State private var launchAtLogin = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 盾牌图标 — 自定义 spring 入场
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.linearGradient(
                    colors: [OB.textPrimary.opacity(0.95), OB.textPrimary.opacity(0.5)],
                    startPoint: .top, endPoint: .bottom
                ))
                .scaleEffect(shieldVisible ? 1 : 0.8)
                .offset(y: shieldVisible ? 0 : 10)
                .opacity(shieldVisible ? 1 : 0)
                .brightness(shieldBrightness)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65),
                    value: shieldVisible
                )
            
            Spacer().frame(height: 24)
            
            Text("Your privacy is non-negotiable.")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(OB.textPrimary)
                .stagger(1, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 28)
            
            OBFeatureCard(items: [
                "Runs entirely offline",
                "No data collection, ever",
                "Only reads system quarantine flags",
                "Open source and auditable",
            ])
            .frame(maxWidth: 380)
            .stagger(2, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 16)
            
            OBToggleCard(isOn: $launchAtLogin)
                .frame(maxWidth: 380)
                .stagger(3, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 36)
            
            Button("Get Started") {
                setLoginItem(enabled: launchAtLogin)
                onGetStarted()
            }
            .buttonStyle(OBButtonStyle(isPrimary: true))
            .stagger(4, appeared: appeared, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, 80)
        .onAppear {
            appeared = true
            shieldVisible = true
            guard !reduceMotion else { return }
            // 盾牌微光脉冲 (t=500ms, 600ms 周期)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) { shieldBrightness = 0.15 }
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

// MARK: - 拟物红绿灯（Onboarding 尺寸）

private struct OBTrafficLight: View {
    let reduceMotion: Bool
    @State private var redIntensity: Double = 0
    @State private var greenIntensity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 金属外壳
            ZStack {
                // 外壳主体：多层渐变模拟金属质感
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [
                            Color(white: 0.32),
                            Color(white: 0.18),
                            Color(white: 0.14),
                            Color(white: 0.20),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.4), Color(white: 0.15)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .frame(width: 44, height: 100)
                
                // 顶部高光线
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 4)
                            .padding(.top, 1)
                    }
                    .frame(width: 44, height: 100)
                
                VStack(spacing: 6) {
                    OBBulb(color: OB.red, intensity: redIntensity)
                    OBBulb(color: OB.amber, intensity: 0.1)
                    OBBulb(color: OB.green, intensity: greenIntensity)
                }
            }
            
            // 柱杆
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.28), Color(white: 0.14), Color(white: 0.22)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: 8, height: 10)
            
            // 底座
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [Color(white: 0.3), Color(white: 0.12)],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color(white: 0.35), lineWidth: 0.5)
                )
                .frame(width: 30, height: 8)
        }
        .onAppear { runSequence() }
    }
    
    private func runSequence() {
        if reduceMotion {
            redIntensity = 0.12
            greenIntensity = 1
            return
        }
        // Phase 1 — 红灯亮 (t=0, 400ms ease-in)
        withAnimation(.easeIn(duration: 0.4)) {
            redIntensity = 1
        }
        // Phase 2 — 红灯灭 + 绿灯亮 (t=600ms, 500ms ease-in-out)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.5)) {
                redIntensity = 0.12
                greenIntensity = 1
            }
        }
    }
}

// MARK: - 灯泡

private struct OBBulb: View {
    let color: Color
    let intensity: Double
    
    var body: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(color.opacity(intensity * 0.35))
                .frame(width: 36, height: 36)
                .blur(radius: 8)
            
            // 球体主体：径向渐变模拟球面光照
            Circle()
                .fill(RadialGradient(
                    colors: [
                        color.opacity(min(intensity + 0.15, 1)),
                        color.opacity(intensity * 0.7),
                        color.opacity(intensity * 0.3),
                    ],
                    center: UnitPoint(x: 0.4, y: 0.35),
                    startRadius: 1, endRadius: 13
                ))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                )
            
            // 玻璃高光点
            Circle()
                .fill(Color.white.opacity(intensity * 0.4))
                .frame(width: 6, height: 5)
                .offset(x: -4, y: -4)
                .blur(radius: 1.5)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - 步骤指示器

private struct OBStepIndicator: View {
    let current: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index == current ? OB.green : Color.white.opacity(0.15))
                    .frame(
                        width: index == current ? 8 : 6,
                        height: index == current ? 8 : 6
                    )
                    .shadow(
                        color: index == current ? OB.green.opacity(0.5) : .clear,
                        radius: 6
                    )
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
    }
}

// MARK: - 特性卡片

private struct OBFeatureCard: View {
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 12) {
                    Circle()
                        .fill(OB.green)
                        .frame(width: 6, height: 6)
                    Text(item)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(OB.textTertiary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(OB.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(OB.cardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Login Item Toggle 卡片

private struct OBToggleCard: View {
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Launch at login")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OB.textPrimary)
                Text("Stay protected around the clock.")
                    .font(.system(size: 12))
                    .foregroundColor(OB.textMuted)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(OB.green)
                .labelsHidden()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(OB.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(OB.cardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - 按钮样式

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
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(isPrimary ? .white : OB.textPrimary)
            .padding(.horizontal, 36)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? OB.green : Color.white.opacity(0.08))
                    .shadow(
                        color: isPrimary ? OB.green.opacity(isHovered ? 0.35 : 0.2) : .clear,
                        radius: isPrimary ? 12 : 0,
                        y: isPrimary ? 4 : 0
                    )
            )
            .brightness(isHovered ? (isPrimary ? 0.08 : 0.12) : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.25), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - 交错入场动画

private struct StaggerModifier: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.4, dampingFraction: 0.75).delay(Double(index) * 0.06),
                value: appeared
            )
    }
}

private extension View {
    func stagger(_ index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        modifier(StaggerModifier(index: index, appeared: appeared, reduceMotion: reduceMotion))
    }
}

// MARK: - Design Tokens

private enum OB {
    static let bg            = Color(red: 15/255, green: 23/255, blue: 42/255)
    static let textPrimary   = Color(red: 248/255, green: 250/255, blue: 252/255)
    static let textSecondary = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.6)
    static let textTertiary  = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.75)
    static let textMuted     = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.4)
    static let green         = Color(red: 34/255,  green: 197/255, blue: 94/255)
    static let red           = Color(red: 239/255, green: 68/255,  blue: 68/255)
    static let amber         = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let cardBg        = Color.white.opacity(0.04)
    static let cardBorder    = Color.white.opacity(0.06)
}
