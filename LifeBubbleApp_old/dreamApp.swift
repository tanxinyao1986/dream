//
//  dreamApp.swift
//  dream
//
//  LifeBubble - 让梦想轻盈地浮现
//

import SwiftUI

@main
struct dreamApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - 应用状态管理
class AppState: ObservableObject {
    @Published var hasCompletedSplash = false
    @Published var currentPage: AppPage = .splash
    @Published var bubbles: [Bubble] = []
    @Published var chatMessages: [ChatMessage] = []

    init() {
        // 初始化示例泡泡
        bubbles = [
            Bubble(text: "每天写500字", type: .core, position: CGPoint(x: 0.5, y: 0.3)),
            Bubble(text: "回复邮件", type: .small, position: CGPoint(x: 0.25, y: 0.45)),
            Bubble(text: "买菜", type: .small, position: CGPoint(x: 0.7, y: 0.4)),
            Bubble(text: "打电话给妈妈", type: .small, position: CGPoint(x: 0.35, y: 0.65)),
            Bubble(text: "整理房间", type: .small, position: CGPoint(x: 0.65, y: 0.7))
        ]

        // 初始AI欢迎消息
        chatMessages = [
            ChatMessage(text: "你好呀，今天想聊点什么？或者，有什么想要实现的小愿望吗？", isUser: false)
        ]
    }

    func completeBubble(_ bubble: Bubble) {
        if let index = bubbles.firstIndex(where: { $0.id == bubble.id }) {
            bubbles.remove(at: index)
        }
    }

    func addChatMessage(_ text: String, isUser: Bool) {
        chatMessages.append(ChatMessage(text: text, isUser: isUser))
    }
}

// MARK: - 数据模型
enum AppPage {
    case splash, home, chat, calendar, archive
}

struct Bubble: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: BubbleType
    var position: CGPoint

    enum BubbleType {
        case core, small
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let type: AchievementType
    let date: Date
    let description: String

    enum AchievementType {
        case major, medium, small
    }
}

struct DayData: Identifiable {
    let id = UUID()
    let day: Int
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool
}
