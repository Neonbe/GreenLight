import SwiftUI
import ServiceManagement

/// 设置窗口
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var updaterManager: UpdaterManager
    @State private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section("通用") {
                Toggle("开机时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
            
            Section("关于") {
                LabeledContent("版本", value: "1.0.0")
                LabeledContent("累计亮绿灯", value: "\(appState.totalGreenLights) 次")
            }
            
            Section("软件更新") {
                Toggle("自动检查更新", isOn: Binding(
                    get: { updaterManager.automaticallyChecksForUpdates },
                    set: { updaterManager.automaticallyChecksForUpdates = $0 }
                ))
                
                Button("检查更新") {
                    updaterManager.checkForUpdates()
                }
                .disabled(!updaterManager.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
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
