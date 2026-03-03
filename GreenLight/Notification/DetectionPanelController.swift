import SwiftUI
import AppKit
import os

/// NSPanel 生命周期管理器
/// 负责创建、定位、显示、隐藏浮动检测面板
@MainActor
final class DetectionPanelController {
    static let shared = DetectionPanelController()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var autoHideTimer: Timer?
    private var currentEvent: GreenLightEvent?
    
    private let remover = QuarantineRemover()
    
    private init() {}
    
    // MARK: - 公开接口
    
    /// 显示检测面板。若已显示则切换内容。
    func show(event: GreenLightEvent) {
        let isAlreadyVisible = panel?.isVisible == true
        currentEvent = event
        AppState.shared.pendingPanelEvent = event
        
        if isAlreadyVisible {
            // 多事件切换：更新内容
            GLLog.panel.info("Panel updated: \(event.appName)")
            updateContent(event: event)
        } else {
            // 首次弹出
            GLLog.panel.notice("Panel created for: \(event.appName)")
            createAndShowPanel(event: event)
        }
        
        resetAutoHideTimer()
    }
    
    /// §r06: 显示确认态面板（Loading 状态，等待 FSEvents 确认具体 app）
    var isConfirming: Bool { _isConfirming }
    private var _isConfirming = false
    
    func showConfirming(foundCount: Int) {
        guard panel?.isVisible != true else {
            GLLog.panel.debug("showConfirming skipped: panel already visible")
            return
        }
        _isConfirming = true
        GLLog.panel.notice("Panel confirming: \(foundCount) found")
        
        let contentView = DetectionConfirmingView(foundCount: foundCount)
        createAndShowPanelWith(AnyView(contentView))
        
        // 确认态 5s 超时（由 GreenLightApp 管线处理，此处不设 auto-hide）
    }
    
    /// §r06: 确认态 → 最终态无缝替换
    func confirmWith(event: GreenLightEvent) {
        _isConfirming = false
        currentEvent = event
        AppState.shared.pendingPanelEvent = event
        
        GLLog.panel.notice("Panel confirmed: \(event.appName)")
        
        if panel?.isVisible == true {
            // 面板已显示（确认态）→ 替换内容
            updateContent(event: event)
        } else {
            // 面板不可见 → 直接创建
            createAndShowPanel(event: event)
        }
        
        resetAutoHideTimer()
    }
    
    /// 关闭面板
    func dismiss() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        currentEvent = nil
        _isConfirming = false
        AppState.shared.pendingPanelEvent = nil
        
        guard let panel = panel else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                panel.orderOut(nil)
                panel.alphaValue = 1
                self?.panel = nil
                self?.hostingView = nil
                GLLog.panel.debug("Panel closed")
            }
        }
    }
    
    // MARK: - 面板创建
    
    private func createAndShowPanel(event: GreenLightEvent) {
        let contentView = makeContentView(event: event)
        createAndShowPanelWith(AnyView(contentView), escEvent: event)
    }
    
    private func createAndShowPanelWith(_ content: AnyView, escEvent: GreenLightEvent? = nil) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 1),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = false  // SwiftUI 视图自带阴影
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // ESC 键支持
        if let event = escEvent {
            panel.addLocalMonitor(for: .keyDown) { [weak self] nsEvent in
                if nsEvent.keyCode == 53 { // ESC
                    GLLog.panel.info("Panel dismissed via ESC")
                    self?.handleDismissAction()
                    return nil
                }
                return nsEvent
            }
        } else {
            // 确认态面板：ESC 直接关闭
            panel.addLocalMonitor(for: .keyDown) { [weak self] nsEvent in
                if nsEvent.keyCode == 53 {
                    GLLog.panel.info("Confirming panel dismissed via ESC")
                    self?._isConfirming = false
                    self?.dismiss()
                    return nil
                }
                return nsEvent
            }
        }
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        
        self.panel = panel
        self.hostingView = hostingView
        
        // 定位到 Menu Bar 图标下方
        positionPanel(panel)
        
        // 先 layout 获取实际尺寸
        hostingView.layout()
        let fittingSize = hostingView.fittingSize
        var frame = panel.frame
        frame.size = fittingSize
        panel.setFrame(frame, display: true)
        positionPanel(panel)
        
        panel.orderFrontRegardless()
    }
    
    // MARK: - 内容更新（多事件切换）
    
    private func updateContent(event: GreenLightEvent) {
        guard let panel = panel else { return }
        
        let contentView = makeContentView(event: event)
        let hostingView = NSHostingView(rootView: AnyView(contentView))
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        self.hostingView = hostingView
        
        // 重新调整尺寸
        hostingView.layout()
        let fittingSize = hostingView.fittingSize
        var frame = panel.frame
        frame.size = fittingSize
        panel.setFrame(frame, display: true)
        positionPanel(panel)
        
        resetAutoHideTimer()
    }
    
    // MARK: - 视图构建
    
    private func makeContentView(event: GreenLightEvent) -> some View {
        DetectionPanelView(
            event: event,
            onDismiss: { [weak self] in
                self?.handleDismissAction()
            },
            onFix: { [weak self] shouldOpen in
                self?.handleFixAction(for: event, shouldOpen: shouldOpen)
            },
            onReject: { [weak self] in
                self?.handleRejectAction(for: event)
            }
        )
    }
    
    // MARK: - 动作处理
    
    /// §6.3: “不做改变”——关闭面板，app 留在 🟡（不改变状态）
    private func handleDismissAction() {
        GLLog.panel.info("User dismissed panel (no state change)")
        dismiss()
    }
    
    /// §4: 丢弃——Move to Trash → 🔴
    private func handleRejectAction(for event: GreenLightEvent) {
        GLLog.panel.info("User reject: \(event.appName)")
        let appState = AppState.shared
        if let record = appState.blockedApps.first(where: { $0.path == event.appPath.path }) {
            appState.rejectApp(record)
        }
        dismiss()
    }
    
    private func handleFixAction(for event: GreenLightEvent, shouldOpen: Bool) {
        GLLog.panel.info("User fix: \(event.appName), shouldOpen=\(shouldOpen)")
        let appPath = event.appPath
        let result = remover.removeQuarantine(at: appPath)
        let appState = AppState.shared
        
        switch result {
        case .success:
            if let record = appState.blockedApps.first(where: { $0.path == appPath.path }) {
                appState.markAsCleared(record)
            }
            if shouldOpen {
                remover.openApp(at: appPath)
            }
            // 成功：延迟后关闭面板
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.dismiss()
            }
            
        case .failure(let error):
            // 失败：ErrorShake 动画（面板不消失）
            if case .needsAdmin(let message, _) = error {
                playErrorShake()
                // 更新面板显示错误信息
                if let currentEvent = currentEvent {
                    let errorView = DetectionPanelErrorView(
                        event: currentEvent,
                        errorMessage: message,
                        onDismiss: { [weak self] in
                            self?.dismiss()
                        }
                    )
                    
                    guard let panel = panel else { return }
                    let hostingView = NSHostingView(rootView: AnyView(errorView))
                    hostingView.frame = panel.contentView?.bounds ?? .zero
                    hostingView.autoresizingMask = [.width, .height]
                    panel.contentView = hostingView
                    self.hostingView = hostingView
                }
            }
        }
    }
    
    // MARK: - 定位
    
    private func positionPanel(_ panel: NSPanel) {
        // 尝试获取 Menu Bar 状态栏按钮位置
        guard let screen = NSScreen.main else { return }
        
        // 查找 NSStatusItem 的窗口位置
        var anchorX = screen.frame.midX
        var anchorY = screen.frame.maxY - screen.frame.height + screen.visibleFrame.height + screen.visibleFrame.origin.y
        
        // 尝试通过 statusItem 窗口定位
        for window in NSApp.windows {
            if window.className.contains("NSStatusBar") ||
               window.level.rawValue > NSWindow.Level.normal.rawValue,
               window.frame.height <= 30,
               window.frame.minY > screen.visibleFrame.maxY - 50 {
                anchorX = window.frame.midX
                anchorY = window.frame.minY
                break
            }
        }
        
        // 面板居中于锚点下方
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let x = anchorX - panelWidth / 2
        let y = anchorY - panelHeight - 8  // 8px 间距
        
        // 确保不超出屏幕边界
        let clampedX = max(screen.frame.minX + 8, min(x, screen.frame.maxX - panelWidth - 8))
        let clampedY = max(screen.visibleFrame.minY, y)
        
        panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        GLLog.panel.debug("Panel positioned at: (\(clampedX), \(clampedY))")
    }
    
    // MARK: - 自动隐藏
    
    private func resetAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                GLLog.panel.info("Panel auto-dismissed (timeout)")
                self?.dismiss()
            }
        }
    }
    
    // MARK: - ErrorShake 动画
    
    private func playErrorShake() {
        guard let panel = panel else { return }
        let offsets: [CGFloat] = [10, -8, 6, -4, 2, 0]
        for (index, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.05
                    var frame = panel.frame
                    frame.origin.x += offset
                    panel.animator().setFrame(frame, display: true)
                }
            }
        }
    }
}

// MARK: - NSPanel ESC 支持扩展

private extension NSPanel {
    func addLocalMonitor(for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
    }
}

// MARK: - 错误状态面板视图

struct DetectionPanelErrorView: View {
    let event: GreenLightEvent
    let errorMessage: String
    let onDismiss: () -> Void
    
    private let bgColor = Color(red: 22/255, green: 28/255, blue: 45/255).opacity(0.95)
    private let glassBorder = Color.white.opacity(0.08)
    private let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let textSecondary = Color(red: 248/255, green: 250/255, blue: 252/255).opacity(0.45)
    private let redColor = Color(red: 239/255, green: 68/255, blue: 68/255)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 状态指示灯
            HStack(spacing: 8) {
                Circle()
                    .fill(redColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: redColor.opacity(0.6), radius: 4)
                
                Text("修复失败")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(redColor)
            }
            
            // App 信息区
            HStack(spacing: 12) {
                let nsImage = NSWorkspace.shared.icon(forFile: event.appPath.path)
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)
                    
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundColor(redColor.opacity(0.8))
                        .lineLimit(2)
                }
            }
            
            // 关闭按钮
            Button(action: onDismiss) {
                Text("关闭")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 320)
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
}
