import SwiftUI
import ServiceManagement

// MARK: - Onboarding 主视图

/// Onboarding 引导流程（2 步：Brand → Trust）
struct OnboardingView: View {
    var onComplete: () -> Void = {}
    var onWarmup: () -> Void = {}  // §r06: 预热回调
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
                    } else if currentStep == 1 {
                        TrustStep(reduceMotion: reduceMotion) {
                            let anim: Animation = reduceMotion
                                ? .linear(duration: 0.15)
                                : .spring(response: 0.45, dampingFraction: 0.88)
                            withAnimation(anim) { currentStep = 2 }
                            GLLog.onboarding.info("Onboarding step: 3")
                        }
                        .transition(pageTransition)
                    } else {
                        ScanningStep(reduceMotion: reduceMotion) {
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
        .onAppear { onWarmup() }  // §r06: Onboarding 开始时触发预热
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
            
            Text("onboarding.brand.title")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(OB.textPrimary)
                .stagger(1, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 16)
            
            Text("onboarding.brand.subtitle")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(OB.textMuted)
                .stagger(2, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 48)
            
            Button("onboarding.continue", action: onContinue)
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
            
            Text("onboarding.trust.title")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(OB.textPrimary)
                .stagger(1, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 12)
            
            Text("onboarding.trust.subtitle")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(OB.textMuted)
                .stagger(2, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 40)
            
            // Toggle 卡片
            OBToggleCard(isOn: $launchAtLogin)
                .frame(maxWidth: 320)
                .stagger(3, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 48)
            
            Button("onboarding.getStarted") {
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

// MARK: - Step 3 · Scanning（扫描过场）

private struct ScanningStep: View {
    let reduceMotion: Bool
    let onComplete: () -> Void
    @EnvironmentObject var appState: AppState
    
    private enum Phase { case scanning, found, clear }
    
    @State private var phase: Phase = .scanning
    @State private var appeared = false
    
    // Shield
    @State private var shieldTint = OB.textPrimary
    @State private var shieldBrightness: Double = 0
    
    // Scanning
    @State private var arcOpacity: Double = 0
    @State private var arcRotation: Double = 0
    @State private var shimmerOffset: CGFloat = -120
    
    // Result
    @State private var animatedCount = 0
    @State private var iconsAppeared = false
    @State private var ctaAppeared = false
    @State private var minDisplayElapsed = false
    @State private var transitioned = false
    
    var body: some View {
        VStack(spacing: 0) {
            shieldView
                .stagger(0, appeared: appeared, reduceMotion: reduceMotion)
            
            Spacer().frame(height: 32)
            
            ZStack {
                if phase == .scanning {
                    scanningContent.transition(.opacity)
                }
                if phase == .found {
                    resultContent.transition(.opacity)
                }
                if phase == .clear {
                    clearContent.transition(.opacity)
                }
            }
        }
        .onAppear {
            appeared = true
            startScanning()
        }
        .onChange(of: appState.detectedApps.count) { _ in
            guard minDisplayElapsed, !transitioned else { return }
            transitioned = true
            transitionToResult()
        }
    }
    
    // MARK: - Shield + Arc
    
    private var shieldView: some View {
        ZStack {
            // 旋转弧线
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(OB.scanBlue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(arcRotation))
                .opacity(arcOpacity)
            
            // 盾牌
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(.linearGradient(
                    colors: [shieldTint.opacity(0.8), shieldTint.opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                ))
                .brightness(shieldBrightness)
        }
    }
    
    // MARK: - Phase 1: Scanning
    
    private var scanningContent: some View {
        VStack(spacing: 16) {
            Text("onboarding.scanning.checking")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(OB.textPrimary)
                .stagger(1, appeared: appeared, reduceMotion: reduceMotion)
            
            shimmerBar
                .stagger(2, appeared: appeared, reduceMotion: reduceMotion)
        }
    }
    
    private var shimmerBar: some View {
        Capsule()
            .fill(Color.white.opacity(0.06))
            .frame(width: 200, height: 2)
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, OB.scanBlue.opacity(0.4), OB.scanBlue.opacity(0.15), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 60)
                    .offset(x: shimmerOffset)
            )
            .clipShape(Capsule())
    }
    
    // MARK: - Phase 2A: Found
    
    private var resultContent: some View {
        VStack(spacing: 0) {
            if animatedCount > 0 {
                Text("\(animatedCount)")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(OB.amber)
            }
            
            Spacer().frame(height: 12)
            
            Text("onboarding.scanning.found \(appState.detectedApps.count)")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(OB.textPrimary)
            
            Spacer().frame(height: 8)
            
            Text("onboarding.scanning.reviewSubtitle")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(OB.textMuted)
            
            Spacer().frame(height: 24)
            
            appIconsRow
            
            Spacer().frame(height: 32)
            
            // CTA
            VStack(spacing: 12) {
                Button("onboarding.scanning.reviewNow", action: onComplete)
                    .buttonStyle(OBButtonStyle(isPrimary: true))
                
                Button("onboarding.scanning.skip", action: onComplete)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(OB.textPrimary.opacity(0.3))
                    .buttonStyle(.plain)
            }
            .opacity(ctaAppeared ? 1 : 0)
            .offset(y: ctaAppeared ? 0 : 10)
            .animation(reduceMotion ? nil : NDAnimation.cardEnter, value: ctaAppeared)
        }
    }
    
    private var appIconsRow: some View {
        let apps = Array(appState.detectedApps.prefix(6))
        let overflow = max(0, appState.detectedApps.count - 6)
        
        return HStack(spacing: 8) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                Group {
                    if let iconData = app.appIcon, let nsImage = NSImage(data: iconData) {
                        Image(nsImage: nsImage).resizable()
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .overlay(
                                Text(String(app.appName.prefix(1)))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 40, height: 40)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.1)))
                .opacity(iconsAppeared ? 1 : 0)
                .scaleEffect(iconsAppeared ? 1 : 0.6)
                .animation(
                    reduceMotion ? nil : NDAnimation.cardEnter.delay(Double(index) * 0.06),
                    value: iconsAppeared
                )
            }
            
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(OB.textMuted)
                    .opacity(iconsAppeared ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : NDAnimation.cardEnter.delay(Double(apps.count) * 0.06),
                        value: iconsAppeared
                    )
            }
        }
    }
    
    // MARK: - Phase 2B: All Clear
    
    private var clearContent: some View {
        VStack(spacing: 0) {
            Text("onboarding.scanning.allClear")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(OB.textPrimary)
            
            Spacer().frame(height: 12)
            
            Text("onboarding.scanning.noIssues")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(OB.textMuted)
            
            Spacer().frame(height: 32)
            
            Button("onboarding.scanning.getStarted", action: onComplete)
                .buttonStyle(OBButtonStyle(isPrimary: true))
                .opacity(ctaAppeared ? 1 : 0)
                .offset(y: ctaAppeared ? 0 : 10)
                .animation(reduceMotion ? nil : NDAnimation.cardEnter, value: ctaAppeared)
        }
    }
    
    // MARK: - Animation Orchestration
    
    private func startScanning() {
        if reduceMotion {
            let count = appState.detectedApps.count
            phase = count > 0 ? .found : .clear
            shieldTint = count > 0 ? OB.amber : OB.green
            animatedCount = count
            iconsAppeared = true
            ctaAppeared = true
            transitioned = true
            return
        }
        
        // Phase 1: 弧线入场 + 旋转 + shimmer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(NDAnimation.cardEnter) { arcOpacity = 1 }
            withAnimation(NDAnimation.scanRotation) { arcRotation = 360 }
            withAnimation(NDAnimation.shimmer) { shimmerOffset = 120 }
        }
        
        // 最小展示时间 0.8s：如果数据已就绪则立即过渡
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            minDisplayElapsed = true
            if appState.detectedApps.count > 0, !transitioned {
                transitioned = true
                transitionToResult()
            }
        }
        
        // 最大等待 3s：无论如何过渡（可能确实 All clear）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard !transitioned else { return }
            transitioned = true
            transitionToResult()
        }
    }
    
    private func transitionToResult() {
        let count = appState.detectedApps.count
        let isFound = count > 0
        
        // 弧线 + shimmer 退场
        withAnimation(NDAnimation.cardExit) { arcOpacity = 0 }
        
        // Phase 切换（crossfade）
        withAnimation(NDAnimation.panelTransition) {
            phase = isFound ? .found : .clear
        }
        
        // 盾牌变色
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                shieldTint = isFound ? OB.amber : OB.green
            }
        }
        
        if isFound {
            // Count-up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                for i in 1...count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 * Double(i)) {
                        animatedCount = i
                    }
                }
            }
            // 图标入场
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                iconsAppeared = true
            }
            // CTA 入场
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(NDAnimation.cardEnter) { ctaAppeared = true }
            }
        } else {
            // 亮闪
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.3)) { shieldBrightness = 0.12 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) { shieldBrightness = 0 }
                }
            }
            // CTA
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(NDAnimation.cardEnter) { ctaAppeared = true }
            }
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
                Text("onboarding.launchAtLogin")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(OB.textPrimary)
                Text("onboarding.launchAtLogin.description")
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
    static let scanBlue      = Color(red: 100/255, green: 180/255, blue: 255/255)
}
