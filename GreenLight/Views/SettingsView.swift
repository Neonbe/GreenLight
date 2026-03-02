import SwiftUI
import ServiceManagement

/// 设置窗口
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var monitoredDirs: [URL] = Persistence.loadMonitoredDirectories() ?? FSEventsWatcher.defaultDirectories
    @State private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section("监控目录") {
                ForEach(monitoredDirs, id: \.path) { dir in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                        Text(dir.path)
                            .font(.system(size: 13))
                        Spacer()
                        Button {
                            monitoredDirs.removeAll { $0 == dir }
                            saveDirectories()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(monitoredDirs.count <= 1)
                    }
                }
                
                Button("添加目录…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        if !monitoredDirs.contains(url) {
                            monitoredDirs.append(url)
                            saveDirectories()
                        }
                    }
                }
            }
            
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
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func saveDirectories() {
        Persistence.saveMonitoredDirectories(monitoredDirs)
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Settings] Login Items 设置失败: \(error)")
        }
    }
}
