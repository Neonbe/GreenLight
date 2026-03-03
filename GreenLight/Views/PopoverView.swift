import SwiftUI

/// Menu Bar Extra 弹窗 — 轻量快捷入口
///
/// 设计理念（implementation_plan.md §2.1）：
/// - 上半部：状态概览（三行 Lane 摘要 + 最近触发 App icon）
/// - 下半部：macOS 标准快捷操作（Show / Settings / Quit）
/// - 底部：品牌特色统计
struct PopoverView: View {
    @EnvironmentObject var appState: AppState
    
    // Design Tokens（与主窗口一致）
    private let bgColor     = Color(red: 15/255, green: 23/255, blue: 42/255)
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let greenColor  = Color(red: 34/255, green: 197/255, blue: 94/255)
    private let redColor    = Color(red: 239/255, green: 68/255, blue: 68/255)
    private let amberColor  = Color(red: 245/255, green: 158/255, blue: 11/255)
    
    var body: some View {
        VStack(spacing: 0) {
            header
            statusOverview
            Divider().background(Color.white.opacity(0.06))
            quickActions
            Divider().background(Color.white.opacity(0.06))
            statusBar
        }
        .frame(width: 280)
        .background(bgColor)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("GREENLIGHT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.2))
                .kerning(3)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
    
    // MARK: - Status Overview（三行 Lane 摘要）
    
    private var statusOverview: some View {
        VStack(spacing: 2) {
            statusRow(
                color: redColor,
                label: "Rejected",
                count: appState.rejectedApps.count,
                recentApp: appState.rejectedApps.last
            )
            statusRow(
                color: amberColor,
                label: "Detected",
                count: appState.detectedApps.count,
                recentApp: appState.detectedApps.last
            )
            statusRow(
                color: greenColor,
                label: "Cleared",
                count: appState.clearedApps.count,
                recentApp: appState.clearedApps.first  // clearedApps 以 insert(at:0) 排序
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private func statusRow(color: Color, label: String, count: Int, recentApp: AppRecord?) -> some View {
        HStack(spacing: 8) {
            // 颜色指示条（始终显示，不置灰）
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 3, height: 22)
            
            // 标签
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.8))
            
            Spacer()
            
            // 计数
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .monospacedDigit()
            
            // 最近触发 App icon（点击 → 跳转主窗口 → 触发 ActionBubble）
            if let app = recentApp {
                Button {
                    navigateToApp(app)
                } label: {
                    appIcon(for: app)
                }
                .buttonStyle(.plain)
            } else {
                // 占位：对齐布局
                Color.clear.frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func appIcon(for app: AppRecord) -> some View {
        Group {
            if let iconData = app.appIcon, let nsImage = NSImage(data: iconData) {
                Image(nsImage: nsImage)
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Text(String(app.appName.prefix(1)))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 24, height: 24)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    // MARK: - Quick Actions（macOS 标准功能）
    
    private var quickActions: some View {
        VStack(spacing: 0) {
            actionButton(icon: "macwindow", label: "Show GreenLight") {
                activateMainWindow()
            }
            
            actionButton(icon: "gearshape", label: "Settings...") {
                openSettings()
            }
            
            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 12)
            
            actionButton(icon: "power", label: "Quit GreenLight") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.4))
                    .frame(width: 18)
                
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Status Bar（品牌特色）
    
    private var statusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(greenColor)
                .frame(width: 5, height: 5)
                .shadow(color: greenColor.opacity(0.35), radius: 3)
            
            Text("累计亮绿灯 \(appState.totalGreenLights) 次")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(greenColor.opacity(0.5))
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - 辅助
    
    /// 点击 App icon → 关闭弹窗 → 激活主窗口 → 触发 ActionBubble
    private func navigateToApp(_ app: AppRecord) {
        dismissPopover()
        // 延迟设置 pendingSelectedApp，确保主窗口完全显示后再触发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.pendingSelectedApp = app
        }
        activateMainWindow()
    }
    
    /// 打开设置窗口
    private func openSettings() {
        dismissPopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // macOS 14+ 使用 showSettingsWindow:，macOS 13 使用 showPreferencesWindow:
            if #available(macOS 14, *) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    /// 激活主窗口
    private func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }
    
    /// 关闭 Menu Bar Extra 弹窗
    private func dismissPopover() {
        // MenuBarExtra .window 样式的弹窗是 NSPanel/NSStatusBarWindow
        for window in NSApp.windows {
            let className = String(describing: type(of: window))
            if className.contains("StatusBar") || className.contains("MenuBarExtra") {
                window.close()
                break
            }
        }
    }
}
