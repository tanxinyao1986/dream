//
//  MainTabView.swift
//  LifeBubble
//
//  备选导航方案 - TabView 导航（当前未使用）
//  当前使用的是基于 AppState 的页面切换
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("主页", systemImage: "circle.grid.3x3.fill")
                }
                .tag(0)

            ChatView()
                .tabItem {
                    Label("AI助手", systemImage: "message.fill")
                }
                .tag(1)

            CalendarView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
                .tag(2)

            ArchiveView()
                .tabItem {
                    Label("档案", systemImage: "star.fill")
                }
                .tag(3)
        }
        .accentColor(Color(hex: "CBA972"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
