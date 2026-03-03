import SwiftUI

/// 主窗口视图 — 首次启动显示 Onboarding，之后显示主仪表盘
struct MainWindowView: View {
    var onWarmup: () -> Void = {}  // §r06: 预热回调
    @State private var showOnboarding = !Persistence.hasCompletedOnboarding
    
    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showOnboarding = false
                    }
                }, onWarmup: onWarmup)
            } else {
                MainDashboardView(enhanceManager: EnhancePromptManager())
            }
        }
    }
}

