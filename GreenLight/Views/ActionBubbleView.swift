import SwiftUI

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
