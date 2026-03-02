import SwiftUI

/// 主窗口视图 — 首次启动显示 Onboarding，之后显示主面板
struct MainWindowView: View {
    @State private var showOnboarding = !Persistence.hasCompletedOnboarding
    
    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showOnboarding = false
                    }
                })
            } else {
                PopoverView()
            }
        }
    }
}
