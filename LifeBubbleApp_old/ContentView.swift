//
//  ContentView.swift
//  LifeBubble
//
//  根视图 - 管理页面导航
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.currentPage {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .home:
                HomeView()
                    .transition(.opacity)

            case .chat:
                ChatView()
                    .transition(.move(edge: .trailing))

            case .calendar:
                CalendarView()
                    .transition(.move(edge: .leading))

            case .archive:
                ArchiveView()
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentPage)
        .statusBarHidden(appState.currentPage == .splash)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
