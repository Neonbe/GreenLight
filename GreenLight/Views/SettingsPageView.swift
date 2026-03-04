import SwiftUI
import ServiceManagement

/// 全屏设置页 — 在 900×620 窗口内切换显示
/// PRD: V1.0.0-r02-主界面重构 §五
struct SettingsPageView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var updaterManager: UpdaterManager
    @State private var launchAtLogin = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let onBack: () -> Void
    
    // MARK: - Design Tokens
    
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let greenColor  = Color(red: 34/255, green: 197/255, blue: 94/255)
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            navBar
                .modifier(SettingsStagger(index: 0, appeared: appeared, reduceMotion: reduceMotion))
            
            Spacer().frame(height: 40)
            
            // 设置内容
            VStack(spacing: 24) {
                // 通用
                settingsSection(title: String(localized: "settings.section.general")) {
                    settingsCard {
                        HStack {
                            Label("settings.launchAtLogin", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(textPrimary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .tint(greenColor)
                                .labelsHidden()
                                .onChange(of: launchAtLogin) { newValue in
                                    setLaunchAtLogin(newValue)
                                }
                        }
                    }
                }
                .modifier(SettingsStagger(index: 1, appeared: appeared, reduceMotion: reduceMotion))
                
                // 关于
                settingsSection(title: String(localized: "settings.section.about")) {
                    settingsCard {
                        VStack(spacing: 0) {
                            settingsRow(label: String(localized: "settings.version"), value: "1.0.0")
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.vertical, 4)
                            
                            settingsRow(label: String(localized: "settings.totalGreenLights"), value: String(localized: "settings.totalGreenLights.value \(appState.totalGreenLights)"))
                        }
                    }
                }
                .modifier(SettingsStagger(index: 2, appeared: appeared, reduceMotion: reduceMotion))
                
                // 反馈
                settingsSection(title: String(localized: "settings.section.feedback")) {
                    settingsCard {
                        VStack(spacing: 0) {
                            settingsLink(
                                icon: "envelope.fill",
                                label: String(localized: "settings.contactUs"),
                                detail: "support@greenlight.app"
                            ) {
                                if let url = URL(string: "mailto:support@greenlight.app") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.vertical, 4)
                            
                            settingsLink(
                                icon: "globe",
                                label: String(localized: "settings.website"),
                                detail: "greenlight.app"
                            ) {
                                if let url = URL(string: "https://greenlight.app") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
                .modifier(SettingsStagger(index: 3, appeared: appeared, reduceMotion: reduceMotion))
                
                // 软件更新
                settingsSection(title: String(localized: "settings.section.updates")) {
                    settingsCard {
                        VStack(spacing: 0) {
                            HStack {
                                Label("settings.autoCheckUpdates", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(textPrimary)
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { updaterManager.automaticallyChecksForUpdates },
                                    set: { updaterManager.automaticallyChecksForUpdates = $0 }
                                ))
                                .toggleStyle(.switch)
                                .tint(greenColor)
                                .labelsHidden()
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.vertical, 4)
                            
                            if let version = updaterManager.availableUpdateVersion {
                                // Plan B：有新版本可用
                                HStack {
                                    Label {
                                        Text("settings.updateAvailable \(version)")
                                    } icon: {
                                        Image(systemName: "arrow.down.circle.fill")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(greenColor)
                                    
                                    Spacer()
                                    
                                    Button(action: { updaterManager.installUpdate() }) {
                                        Text("settings.installUpdate")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(greenColor)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                // 常规态：检查更新
                                HStack {
                                    Label("settings.checkForUpdates", systemImage: "arrow.clockwise.circle")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(textPrimary)
                                    
                                    Spacer()
                                    
                                    if let lastCheck = updaterManager.lastUpdateCheckDate {
                                        Text(lastCheck, style: .relative)
                                            .font(.system(size: 11, weight: .light))
                                            .foregroundColor(textPrimary.opacity(0.4))
                                    }
                                    
                                    Button(action: { updaterManager.checkForUpdates() }) {
                                        Text("settings.check")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(greenColor.opacity(0.8))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!updaterManager.canCheckForUpdates)
                                    .opacity(updaterManager.canCheckForUpdates ? 1 : 0.5)
                                }
                            }
                        }
                    }
                }
                .modifier(SettingsStagger(index: 4, appeared: appeared, reduceMotion: reduceMotion))
            }
            .frame(maxWidth: 480)
            
            Spacer()
        }
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            appeared = true
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navBar: some View {
        ZStack {
            // 居中标题
            Text("settings.title")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(textPrimary)
            
            // 左侧返回按钮
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .light))
                        Text("settings.back")
                            .font(.system(size: 14, weight: .light))
                    }
                    .foregroundColor(textPrimary.opacity(0.5))
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding(.horizontal, 80)
        .padding(.top, 32)
    }
    
    // MARK: - Section Builder
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(textPrimary.opacity(0.3))
                .kerning(1.5)
                .textCase(.uppercase)
            
            content()
        }
    }
    
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.05))
                    )
            )
    }
    
    // MARK: - Row Components
    
    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(textPrimary.opacity(0.5))
        }
    }
    
    private func settingsLink(icon: String, label: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.4))
                    .frame(width: 20)
                
                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text(detail)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(textPrimary.opacity(0.4))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(textPrimary.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            GLLog.state.error("Login Items 设置失败: \(error)")
        }
    }
}

// MARK: - Settings Stagger Animation

private struct SettingsStagger: ViewModifier {
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
                    : .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.06),
                value: appeared
            )
    }
}
