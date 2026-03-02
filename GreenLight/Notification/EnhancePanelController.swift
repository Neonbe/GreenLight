import SwiftUI
import AppKit

/// "Enhance Protection?" 引导面板控制器（§3.2）
/// 复用 DetectionPanelController 的面板定位逻辑
@MainActor
final class EnhancePanelController {
    static let shared = EnhancePanelController()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    
    private init() {}
    
    // MARK: - 显示
    
    func show(enhanceManager: EnhancePromptManager) {
        guard panel == nil else {
            GLLog.enhance.debug("Enhance panel already visible, skip")
            return
        }
        
        GLLog.enhance.notice("Showing enhance protection panel")
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 1),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // ESC 键关闭
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] nsEvent in
            if nsEvent.keyCode == 53 {
                GLLog.enhance.info("Enhance panel dismissed via ESC")
                enhanceManager.dismissedByUser()
                self?.dismiss()
                return nil
            }
            return nsEvent
        }
        
        let contentView = EnhancePanelView(
            onGrantAccess: { [weak self] in
                GLLog.enhance.notice("User tapped Grant Access")
                self?.dismiss()
                // 依次触发 TCC 目录访问（§3.3）
                enhanceManager.attemptUpgradeToLevel1()
            },
            onNotNow: { [weak self] in
                GLLog.enhance.info("User tapped Not Now")
                enhanceManager.dismissedByUser()
                self?.dismiss()
            }
        )
        
        let hostingView = NSHostingView(rootView: AnyView(contentView))
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        
        self.panel = panel
        self.hostingView = hostingView
        
        // 定位到 Menu Bar 下方
        positionPanel(panel)
        
        hostingView.layout()
        let fittingSize = hostingView.fittingSize
        var frame = panel.frame
        frame.size = fittingSize
        panel.setFrame(frame, display: true)
        positionPanel(panel)
        
        panel.orderFrontRegardless()
    }
    
    // MARK: - 关闭
    
    func dismiss() {
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
                GLLog.enhance.debug("Enhance panel closed")
            }
        }
    }
    
    // MARK: - 定位（复用 DetectionPanelController 的逻辑）
    
    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        
        var anchorX = screen.frame.midX
        var anchorY = screen.frame.maxY - screen.frame.height + screen.visibleFrame.height + screen.visibleFrame.origin.y
        
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
        
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let x = anchorX - panelWidth / 2
        let y = anchorY - panelHeight - 8
        
        let clampedX = max(screen.frame.minX + 8, min(x, screen.frame.maxX - panelWidth - 8))
        let clampedY = max(screen.visibleFrame.minY, y)
        
        panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
}
