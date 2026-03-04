import SwiftUI
import UniformTypeIdentifiers

/// 主窗口仪表盘 — 900×620 全尺寸主界面
/// PRD: V1.0.0-r02-主界面重构 §三
struct MainDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var selectedApp: AppRecord?
    @State private var showExpandCoverage = false
    @State private var appeared = false
    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let enhanceManager: EnhancePromptManager
    
    // MARK: - Design Tokens (ui_design_spec.md §2.1)
    
    private let bgColor     = Color(red: 15/255, green: 23/255, blue: 42/255)
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let greenColor  = Color(red: 34/255, green: 197/255, blue: 94/255)
    private let redColor    = Color(red: 239/255, green: 68/255, blue: 68/255)
    private let amberColor  = Color(red: 245/255, green: 158/255, blue: 11/255)
    
    var body: some View {
        ZStack {
            // 背景：复用 Onboarding 风格
            bgColor.ignoresSafeArea()
            RadialGradient(
                colors: [Color.white.opacity(0.025), Color.clear],
                center: .center,
                startRadius: 60,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            if showSettings {
                SettingsPageView(onBack: {
                    withAnimation(NDAnimation.panelTransition) {
                        showSettings = false
                    }
                })
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            } else {
                dashboardContent
                    .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
            }
            
            // Drop Zone 覆盖层
            if isDropTargeted {
                DropZoneOverlay(reduceMotion: reduceMotion)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isDropTargeted)
            }
        }
        .frame(width: 900, height: 620)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleWindowDrop(providers: providers)
            return true
        }
        .onChange(of: appState.pendingSelectedApp?.id) { _ in
            // Menu Bar Extra 点击 App icon → 自动弹出 ActionBubble
            guard let app = appState.pendingSelectedApp else { return }
            appState.pendingSelectedApp = nil
            // 如果在 Settings 页面，先切回 Dashboard
            if showSettings {
                withAnimation(NDAnimation.panelTransition) {
                    showSettings = false
                }
            }
            // 延迟一帧确保 Dashboard 完成渲染
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                selectedApp = app
            }
        }
    }
    
    // MARK: - Dashboard Content
    
    private var dashboardContent: some View {
        VStack(spacing: 0) {
            header
                .modifier(DashboardStagger(index: 0, appeared: appeared, reduceMotion: reduceMotion))
            
            Spacer()
            
            mainContent
            
            Spacer()
            
            if showExpandCoverage {
                expandCoverageCard
            }
            
            footer
                .modifier(DashboardStagger(index: 6, appeared: appeared, reduceMotion: reduceMotion))
        }
        .onAppear { appeared = true }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("dashboard.header")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(textPrimary.opacity(0.25))
            
            Spacer()
            
            scanButton
        }
        .padding(.horizontal, 80)
        .padding(.top, 32)
    }
    
    private var scanButton: some View {
        Button(action: startScan) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.04))
                )
                .rotationEffect(.degrees(appState.isScanning ? 360 : 0))
                .animation(
                    appState.isScanning
                        ? .linear(duration: 1.2).repeatForever(autoreverses: false)
                        : .linear(duration: 0.3),
                    value: appState.isScanning
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        HStack(alignment: .center, spacing: 0) {
            trafficLight
                .modifier(DashboardStagger(index: 1, appeared: appeared, reduceMotion: reduceMotion))
            
            VStack(spacing: 6) {
                laneView(
                    color: redColor,
                    label: String(localized: "dashboard.lane.rejected"),
                    count: appState.rejectedApps.count,
                    apps: appState.rejectedApps,
                    emptyText: String(localized: "dashboard.lane.noRejected"),
                    staggerIndex: 2
                )
                
                laneView(
                    color: amberColor,
                    label: String(localized: "dashboard.lane.detected"),
                    count: appState.detectedApps.count,
                    apps: appState.detectedApps,
                    emptyText: String(localized: "dashboard.lane.noDetected"),
                    staggerIndex: 3
                )
                
                laneView(
                    color: greenColor,
                    label: String(localized: "dashboard.lane.cleared"),
                    count: appState.clearedApps.count,
                    apps: appState.clearedApps,
                    emptyText: String(localized: "dashboard.lane.noCleared"),
                    staggerIndex: 4
                )
            }
            .padding(.leading, -8)
        }
        .padding(.horizontal, 80)
    }
    
    // MARK: - Traffic Light (§6.3: 40px 灯泡, 68px 外壳)
    
    private var trafficLight: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                lightBulb(color: redColor, isActive: !appState.rejectedApps.isEmpty)
                lightBulb(color: amberColor, isActive: !appState.detectedApps.isEmpty)
                lightBulb(color: greenColor, isActive: !appState.clearedApps.isEmpty)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.23), Color(white: 0.17),
                                Color(white: 0.11), Color(white: 0.08), Color(white: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.38), Color(white: 0.12)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 3, y: 0)
            )
            
            // 灯柱
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.11), Color(white: 0.23), Color(white: 0.17), Color(white: 0.10)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 16, height: 32)
            
            // 底座
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.11), Color(white: 0.23), Color(white: 0.17), Color(white: 0.10)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 50, height: 10)
        }
    }
    
    private func lightBulb(color: Color, isActive: Bool) -> some View {
        ZStack {
            // 光晕
            Circle()
                .fill(color.opacity(isActive ? 0.3 : 0))
                .frame(width: 56, height: 56)
                .blur(radius: 14)
            
            // 球体
            Circle()
                .fill(
                    RadialGradient(
                        colors: isActive
                            ? [color.opacity(1), color.opacity(0.65), color.opacity(0.2)]
                            : [color.opacity(0.15), color.opacity(0.08)],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
            
            // 高光
            Circle()
                .fill(Color.white.opacity(isActive ? 0.4 : 0.08))
                .frame(width: 10, height: 8)
                .offset(x: -6, y: -7)
                .blur(radius: 2)
        }
        .frame(width: 40, height: 40)
        .shadow(color: isActive ? color.opacity(0.35) : .clear, radius: 14)
    }
    
    // MARK: - Lane View (§6.4)
    
    private func laneView(
        color: Color, label: String, count: Int,
        apps: [AppRecord], emptyText: String, staggerIndex: Int
    ) -> some View {
        HStack(spacing: 12) {
            // Info（标签 + 计数）
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(textPrimary.opacity(0.3))
                    .kerning(2)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(color)
                } else {
                    Text(emptyText)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(textPrimary.opacity(0.2))
                }
            }
            .frame(minWidth: 80, alignment: .leading)
            
            if count > 0 {
                // 分隔线
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 40)
                
                // App 图标区（方案 A：横向滚动 + 渐隐遮罩）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            appIconView(app: app, laneColor: color)
                                .modifier(DashboardStagger(
                                    index: staggerIndex + index,
                                    appeared: appeared,
                                    reduceMotion: reduceMotion
                                ))
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .padding(.leading, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.04))
                )
        )
        .overlay(alignment: .leading) {
            // 左侧霓虹线
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, 10)
                .shadow(color: color, radius: 6)
        }
        .modifier(DashboardStagger(index: staggerIndex, appeared: appeared, reduceMotion: reduceMotion))
    }
    
    // MARK: - App Icon
    
    private func appIconView(app: AppRecord, laneColor: Color) -> some View {
        Button {
            selectedApp = (selectedApp?.id == app.id) ? nil : app
        } label: {
            Group {
                if let iconData = app.appIcon, let nsImage = NSImage(data: iconData) {
                    Image(nsImage: nsImage)
                        .resizable()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(String(app.appName.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 40, height: 40)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.1))
            )
        }
        .buttonStyle(AppIconButtonStyle())
        .popover(isPresented: Binding(
            get: { selectedApp?.id == app.id },
            set: { if !$0 { selectedApp = nil } }
        )) {
            ActionBubbleView(app: app, laneColor: laneColor)
                .environmentObject(appState)
        }
    }
    
    // MARK: - Expand Coverage Card (§3.5)
    
    private var expandCoverageCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("dashboard.expandCoverage.title")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("dashboard.expandCoverage.subtitle")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Button("dashboard.expandCoverage.button") {
                showExpandCoverage = false
                enhanceManager.requestEnhance()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.blue)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.blue.opacity(0.15))
                )
        )
        .padding(.horizontal, 80)
        .padding(.bottom, 8)
    }
    
    // MARK: - Footer (§6.5)
    
    private var footer: some View {
        HStack {
            // 左侧：设置入口
            Button {
                withAnimation(NDAnimation.panelTransition) {
                    showSettings = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("dashboard.settings")
                        .font(.system(size: 11, weight: .light))
                }
                .foregroundColor(textPrimary.opacity(0.3))
            }
            .buttonStyle(FooterButtonStyle())
            
            Spacer()
            
            // 右侧：累计绿灯数
            HStack(spacing: 6) {
                Circle()
                    .fill(greenColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: greenColor.opacity(0.35), radius: 3)
                
                Text("dashboard.totalGreenLights \(appState.totalGreenLights)")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(greenColor.opacity(0.4))
            }
        }
        .padding(.horizontal, 80)
        .padding(.bottom, 24)
    }
    
    // MARK: - Scan (复用 PopoverView 逻辑)
    
    private func startScan() {
        guard !appState.isScanning else { return }
        appState.isScanning = true
        showExpandCoverage = false
        
        Task.detached {
            let watcher = FSEventsWatcher()
            
            var scanDirs = FSEventsWatcher.level0Directories
            let hasUngrantedDirs: Bool
            
            if Persistence.level1Granted {
                scanDirs += FSEventsWatcher.level1Directories
                hasUngrantedDirs = false
            } else {
                hasUngrantedDirs = true
            }
            
            let events = watcher.scanApps(in: scanDirs)
            let shouldShowExpand = hasUngrantedDirs
            
            await MainActor.run {
                let deduplicator = EventDeduplicator(windowDuration: 0)
                deduplicator.onEvent = { event in
                    AppState.shared.addDetectedApp(from: event)
                }
                for event in events {
                    deduplicator.receive(event)
                }
                appState.isScanning = false
                
                if shouldShowExpand {
                    showExpandCoverage = true
                }
            }
        }
    }
    
    // MARK: - Window Drop
    
    private func handleWindowDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                guard url.pathExtension == "app" else {
                    GLLog.pipeline.notice("Window drop: not an app bundle: \(url.lastPathComponent)")
                    return
                }
                
                guard FileManager.default.fileExists(atPath: url.path) else {
                    GLLog.pipeline.notice("Window drop: file not found: \(url.path)")
                    return
                }
                
                Task { @MainActor in
                    guard FSEventsWatcher.hasQuarantine(at: url.path) else {
                        GLLog.pipeline.info("Window drop: no quarantine on \(url.lastPathComponent)")
                        return
                    }
                    
                    let appName = url.deletingPathExtension().lastPathComponent
                    let bundleId = Bundle(url: url)?.bundleIdentifier
                    let event = GreenLightEvent(
                        appPath: url,
                        appName: appName,
                        bundleId: bundleId,
                        sources: [.dockDrop],
                        timestamp: Date()
                    )
                    
                    GLLog.pipeline.notice("Window drop: \(appName), showing panel")
                    
                    let appState = AppState.shared
                    if !appState.blockedApps.contains(where: { $0.path == url.path }) {
                        appState.addDetectedApp(from: event)
                    }
                    
                    DetectionPanelController.shared.show(event: event)
                }
            }
        }
    }
}

// MARK: - App Icon Button Style (§7.3)

private struct AppIconButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : (isHovered ? 1.15 : 1))
            .offset(y: isHovered ? -2 : 0)
            .shadow(color: .black.opacity(isHovered ? 0.3 : 0), radius: 8, y: 4)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isHovered)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Footer Button Style

private struct FooterButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(isHovered ? 0.3 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Dashboard Stagger Animation (§7.2)

private struct DashboardStagger: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(
                reduceMotion
                    ? nil
                    : NDAnimation.cardEnter.delay(0.08 + Double(index) * NDAnimation.staggerInterval),
                value: appeared
            )
    }
}

// MARK: - Drop Zone Overlay（拖拽修复 §8.2）

/// 拖放目标覆盖层：绿色呼吸虚线边框 + 中心下箭头 + 半透明遮罩
private struct DropZoneOverlay: View {
    let reduceMotion: Bool
    
    @State private var dashPhase: CGFloat = 0
    @State private var iconScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0.15
    
    private let greenColor = Color(red: 34/255, green: 197/255, blue: 94/255)
    private let bgColor    = Color(red: 15/255, green: 23/255, blue: 42/255)
    
    var body: some View {
        ZStack {
            // 半透明遮罩
            bgColor.opacity(0.85)
            
            // 虚线边框
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6], dashPhase: dashPhase)
                )
                .foregroundColor(greenColor.opacity(0.5))
                .padding(24)
            
            // 中心内容
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(greenColor.opacity(0.5))
                    .scaleEffect(iconScale)
                
                Text("dropzone.hint")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.6))
            }
        }
        .shadow(color: greenColor.opacity(glowOpacity), radius: 30)
        .accessibilityLabel(Text("dropzone.accessibility"))
        .onAppear {
            guard !reduceMotion else {
                iconScale = 1.0
                return
            }
            // 虚线流动动画
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                dashPhase = 28  // dash + gap = 8 + 6 = 14, 两个周期
            }
            // 中心图标弹入
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                iconScale = 1.0
            }
            // 光晕脉冲
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.25
            }
        }
    }
}
