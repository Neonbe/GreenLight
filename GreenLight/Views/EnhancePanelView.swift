import SwiftUI

/// "Enhance Protection?" 引导面板视图（§3.2）
struct EnhancePanelView: View {
    let onGrantAccess: () -> Void
    let onNotNow: () -> Void
    
    private let bgColor = Color(red: 22/255, green: 28/255, blue: 45/255).opacity(0.95)
    private let glassBorder = Color.white.opacity(0.08)
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let textSecondary = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.55)
    private let accentBlue = Color(red: 59/255, green: 130/255, blue: 246/255)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accentBlue)
                
                Text("Enhance Protection?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            // 原因说明
            Text("GreenLight detected Gatekeeper activity but couldn't fully verify the file location.")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
                .lineSpacing(2)
            
            // 请求说明
            Text("Grant access to Downloads and Desktop for comprehensive monitoring — files are only scanned locally, nothing is uploaded or shared.")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
                .lineSpacing(2)
            
            // 目录列表
            VStack(spacing: 6) {
                directoryRow("Downloads")
                directoryRow("Desktop")
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
            )
            
            // 按钮
            HStack(spacing: 10) {
                Spacer()
                
                Button(action: onNotNow) {
                    Text("Not Now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: onGrantAccess) {
                    Text("Grant Access")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentBlue)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(glassBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 20)
    }
    
    private func directoryRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(accentBlue.opacity(0.7))
            
            Text("~/\(name)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary.opacity(0.8))
            
            Spacer()
        }
    }
}
