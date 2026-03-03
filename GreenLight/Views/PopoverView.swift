import SwiftUI

/// Menu Bar Popover 主面板
struct PopoverView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedApp: AppRecord?
    @State private var showExpandCoverage = false
    
    let enhanceManager: EnhancePromptManager
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header
            
            // 主体：红绿灯 + Lane
            mainContent
            
            // Expand Coverage 提示卡片（§八）
            if showExpandCoverage {
                expandCoverageCard
            }
            
            // 底部状态栏
            statusBar
        }
        .frame(width: 420, height: showExpandCoverage ? 460 : 420)
        .background(Color(nsColor: NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("GREENLIGHT")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .kerning(4.5)
            
            Spacer()
            
            headerButton(systemImage: "arrow.triangle.2.circlepath") {
                startScan()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }
    
    private func headerButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 0) {
            // 红绿灯
            trafficLight
            
            // Lanes
            VStack(spacing: 6) {
                // 🔴 红灯 Lane — REJECTED
                laneView(
                    color: .red,
                    label: "REJECTED",
                    count: appState.rejectedApps.count,
                    apps: appState.rejectedApps
                )
                
                // 🟡 黄灯 Lane — DETECTED（待处理）
                laneView(
                    color: .yellow,
                    label: "DETECTED",
                    count: appState.detectedApps.count,
                    apps: appState.detectedApps
                )
                
                // 🟢 绿灯 Lane — CLEARED
                laneView(
                    color: .green,
                    label: "CLEARED",
                    count: appState.clearedApps.count,
                    apps: appState.clearedApps
                )
            }
            .padding(.leading, -8)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Expand Coverage Card（§八）
    
    private var expandCoverageCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Only /Applications was scanned.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Grant access to Downloads and Desktop for a complete scan.")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Button("Expand Coverage") {
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
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    // MARK: - Traffic Light
    
    private var trafficLight: some View {
        VStack(spacing: 0) {
            // 灯体
            VStack(spacing: 5) {
                lightBulb(color: .red, isActive: !appState.rejectedApps.isEmpty)
                lightBulb(color: .yellow, isActive: !appState.detectedApps.isEmpty)
                lightBulb(color: .green, isActive: !appState.clearedApps.isEmpty)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 13)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.23),
                                Color(white: 0.17),
                                Color(white: 0.11),
                                Color(white: 0.08),
                                Color(white: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 3, y: 0)
            )
            
            // 灯柱
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.11), Color(white: 0.23), Color(white: 0.17), Color(white: 0.10)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 14, height: 28)
            
            // 底座
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.11), Color(white: 0.23), Color(white: 0.17), Color(white: 0.10)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 44, height: 8)
        }
    }
    
    private func lightBulb(color: Color, isActive: Bool) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: isActive ? activeColors(for: color) : dimColors(for: color),
                    center: UnitPoint(x: 0.4, y: 0.35),
                    startRadius: 2,
                    endRadius: 25
                )
            )
            .frame(width: 36, height: 36)
            .shadow(color: isActive ? color.opacity(0.35) : .clear, radius: 14)
            .overlay(
                Circle()
                    .strokeBorder(Color.black.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                // 高光反射
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(isActive ? 0.4 : 0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 10
                        )
                    )
                    .frame(width: 14, height: 10)
                    .offset(x: -4, y: -6)
                    .blur(radius: 2)
            )
    }
    
    private func activeColors(for color: Color) -> [Color] {
        switch color {
        case .red: return [Color(red: 1, green: 0.54, blue: 0.54), .red, Color(red: 0.72, green: 0.11, blue: 0.11)]
        case .yellow: return [Color(red: 0.99, green: 0.9, blue: 0.54), .yellow, Color(red: 0.85, green: 0.47, blue: 0.04)]
        case .green: return [Color(red: 0.65, green: 0.95, blue: 0.82), .green, Color(red: 0.08, green: 0.5, blue: 0.24)]
        default: return [.gray]
        }
    }
    
    private func dimColors(for color: Color) -> [Color] {
        switch color {
        case .red: return [Color(red: 0.3, green: 0.1, blue: 0.1), Color(red: 0.2, green: 0.08, blue: 0.08)]
        case .yellow: return [Color(red: 0.3, green: 0.25, blue: 0.1), Color(red: 0.2, green: 0.15, blue: 0.06)]
        case .green: return [Color(red: 0.1, green: 0.2, blue: 0.1), Color(red: 0.06, green: 0.15, blue: 0.08)]
        default: return [.gray]
        }
    }
    
    // MARK: - Lane View
    
    private func laneView(color: Color, label: String, count: Int, apps: [AppRecord]) -> some View {
        HStack(spacing: 12) {
            // Info（标签 + 计数）
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
                    .kerning(1.5)
                
                Text("\(count)")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(color)
            }
            .frame(minWidth: 52, alignment: .leading)
            
            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: 34)
            
            // App 图标区
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(apps) { app in
                        appIconView(app: app, laneColor: color)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .padding(.leading, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.03))
                )
        )
        .overlay(alignment: .leading) {
            // 左侧霓虹线
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 2.5)
                .padding(.vertical, 8)
                .shadow(color: color, radius: 5)
        }
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
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { selectedApp?.id == app.id },
            set: { if !$0 { selectedApp = nil } }
        )) {
            ActionBubbleView(app: app, laneColor: laneColor)
                .environmentObject(appState)
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.04))
            
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: .green.opacity(0.35), radius: 3)
                
                Text("累计亮绿灯 \(appState.totalGreenLights) 次")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green.opacity(0.75))
            }
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - 扫描（§八）
    
    private func startScan() {
        guard !appState.isScanning else { return }
        appState.isScanning = true
        showExpandCoverage = false
        
        Task.detached {
            let watcher = FSEventsWatcher()
            
            // 根据授权状态确定可扫描目录（不触发 TCC）
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
                let deduplicator = EventDeduplicator(windowDuration: 0) // 扫描模式不去重
                deduplicator.onEvent = { event in
                    AppState.shared.addDetectedApp(from: event)
                }
                for event in events {
                    deduplicator.receive(event)
                }
                appState.isScanning = false
                
                // 有未授权目录时显示 Expand Coverage 提示
                if shouldShowExpand {
                    showExpandCoverage = true
                }
            }
        }
    }
}

/// 操作气泡（点击 app 图标后弹出）
struct ActionBubbleView: View {
    let app: AppRecord
    let laneColor: Color
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    private let remover = QuarantineRemover()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：图标 + 名称 + 路径
            HStack(spacing: 10) {
                if let iconData = app.appIcon, let nsImage = NSImage(data: iconData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .frame(width: 36, height: 36)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(app.path)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // 操作按钮
            if app.status == .detected {
                HStack(spacing: 8) {
                    Button("🔓 放行") {
                        fix(shouldOpen: false)
                    }
                    .buttonStyle(ActionButtonStyle(isPrimary: false))
                    
                    Button("▶ 放行并打开") {
                        fix(shouldOpen: true)
                    }
                    .buttonStyle(ActionButtonStyle(isPrimary: true))
                }
            } else if app.status == .cleared {
                HStack(spacing: 8) {
                    Button("📂 在 Finder 中显示") {
                        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
                        dismiss()
                    }
                    .buttonStyle(ActionButtonStyle(isPrimary: false))
                    
                    if app.greenLightCount > 0 {
                        Text("绿灯 ×\(app.greenLightCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green.opacity(0.7))
                    }
                }
            }
            // .rejected 状态不显示操作按钮（占位符历史记录）
        }
        .padding(16)
        .frame(minWidth: 220)
        .background(Color(red: 0.086, green: 0.11, blue: 0.176).opacity(0.97))
    }
    
    private func fix(shouldOpen: Bool) {
        let appPath = URL(fileURLWithPath: app.path)
        let result = remover.removeQuarantine(at: appPath)
        
        switch result {
        case .success:
            appState.markAsCleared(app)
            if shouldOpen {
                remover.openApp(at: appPath)
            }
            dismiss()
            
        case .failure(let error):
            if case .needsAdmin(_, let command) = error {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            }
        }
    }
}

/// 操作按钮样式
struct ActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isPrimary ? .white : .white.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPrimary ? Color.green : Color.white.opacity(0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
