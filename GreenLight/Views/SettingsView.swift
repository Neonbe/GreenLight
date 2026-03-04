import SwiftUI
import ServiceManagement

/// 设置窗口（⌘, 打开） — 与 SettingsPageView 风格对齐
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var launchAtLogin = false
    
    // Design Tokens（与 SettingsPageView 一致）
    private let bgColor     = Color(red: 15/255, green: 23/255, blue: 42/255)
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let greenColor  = Color(red: 34/255, green: 197/255, blue: 94/255)
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题
                Text("settings.title")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(textPrimary)
                    .padding(.top, 28)
                
                Spacer().frame(height: 32)
                
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
                }
                .frame(maxWidth: 400)
                
                Spacer()
            }
        }
        .frame(width: 480, height: 420)
        .preferredColorScheme(.dark)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    // MARK: - Components（复用 SettingsPageView 同款组件）
    
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
