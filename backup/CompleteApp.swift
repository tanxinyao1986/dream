//
//  CompleteApp.swift
//  LifeBubble 完整单文件版本
//
//  使用方法：
//  1. 在Xcode中创建新项目（iOS App, SwiftUI）
//  2. 删除默认的 ContentView.swift
//  3. 将此文件拖入项目，替换默认的 @main 文件
//  4. 运行即可
//

import SwiftUI

// MARK: - ========== 应用入口 ==========
@main
struct LifeBubbleApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - ========== 根视图 ==========
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.currentPage {
            case .splash:
                SplashView()
            case .home:
                HomeView()
            case .chat:
                ChatView()
            case .calendar:
                CalendarView()
            case .archive:
                ArchiveView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentPage)
    }
}

// MARK: - ========== 数据模型 ==========
class AppState: ObservableObject {
    @Published var currentPage: AppPage = .splash
    @Published var bubbles: [Bubble] = []
    @Published var chatMessages: [ChatMessage] = []

    init() {
        bubbles = [
            Bubble(text: "每天写500字", type: .core, position: CGPoint(x: 0.5, y: 0.3)),
            Bubble(text: "回复邮件", type: .small, position: CGPoint(x: 0.25, y: 0.45)),
            Bubble(text: "买菜", type: .small, position: CGPoint(x: 0.7, y: 0.4)),
            Bubble(text: "打电话给妈妈", type: .small, position: CGPoint(x: 0.35, y: 0.65)),
            Bubble(text: "整理房间", type: .small, position: CGPoint(x: 0.65, y: 0.7))
        ]

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
}

// MARK: - ========== 1. 启动页 ==========
struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 1.0
    @State private var isPressed = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 60) {
                Spacer()

                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.9), Color(hex: "CBA972").opacity(0.4)], center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 200)
                    .shadow(color: Color(hex: "CBA972").opacity(0.6), radius: 40)
                    .scaleEffect(isPressed ? 1.5 : scale)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: scale)
                    .onAppear { scale = 1.05 }
                    .onLongPressGesture(minimumDuration: 1.0, perform: {
                        appState.currentPage = .home
                    }) { pressing in
                        isPressed = pressing
                    }

                Spacer()

                Text("今天，让我们从一个小小的愿望开始")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "CBA972"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("长按光球进入")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B6B6B").opacity(0.5))
                    .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - ========== 2. 主页 ==========
struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: { appState.currentPage = .calendar }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    Button(action: { appState.currentPage = .archive }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding()

                GeometryReader { geo in
                    ForEach(appState.bubbles) { bubble in
                        BubbleView(bubble: bubble, size: geo.size)
                            .onTapGesture {
                                withAnimation { appState.completeBubble(bubble) }
                            }
                    }
                }

                Button(action: { appState.currentPage = .chat }) {
                    Circle()
                        .fill(LinearGradient(colors: [.white.opacity(0.5), Color(hex: "CBA972").opacity(0.3)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 70, height: 70)
                        .overlay(Text("+").font(.system(size: 32)).foregroundColor(Color(hex: "CBA972")))
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct BubbleView: View {
    let bubble: Bubble
    let size: CGSize

    var bubbleSize: CGFloat { bubble.type == .core ? 140 : 80 }
    var color: Color { bubble.type == .core ? Color(hex: "FFB6C1").opacity(0.7) : Color(hex: "E8E8E8").opacity(0.6) }

    var body: some View {
        Circle()
            .fill(color)
            .overlay(Text(bubble.text).font(.system(size: bubble.type == .core ? 15 : 12)).foregroundColor(Color(hex: "6B6B6B")).padding(10))
            .frame(width: bubbleSize, height: bubbleSize)
            .position(x: bubble.position.x * size.width, y: bubble.position.y * size.height)
    }
}

// MARK: - ========== 3. AI对话 ==========
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: { appState.currentPage = .home }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                }
                .padding()

                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.9), Color(hex: "ADD8E6").opacity(0.6), Color(hex: "CBA972").opacity(0.4)], center: .center, startRadius: 0, endRadius: 90))
                    .frame(width: 180, height: 180)
                    .padding(.vertical, 30)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.chatMessages) { msg in
                            HStack {
                                if msg.isUser { Spacer() }
                                Text(msg.text)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 18).fill(msg.isUser ? Color.white.opacity(0.6) : Color(hex: "ADD8E6").opacity(0.3)))
                                if !msg.isUser { Spacer() }
                            }
                        }
                    }
                    .padding()
                }

                HStack {
                    TextField("说说你的想法...", text: $inputText)
                        .padding(12)
                        .background(Capsule().fill(.white.opacity(0.7)))

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .background(Circle().fill(Color(hex: "CBA972").opacity(0.6)))
                    }
                }
                .padding()
            }
        }
    }

    func sendMessage() {
        guard !inputText.isEmpty else { return }
        appState.addChatMessage(inputText, isUser: true)
        inputText = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let responses = ["这是一个很棒的想法！", "我们可以从小步开始。", "今天有点累也没关系。"]
            appState.addChatMessage(responses.randomElement()!, isUser: false)
        }
    }
}

// MARK: - ========== 4. 日历 ==========
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "2C2C3E"), Color(hex: "1C1C2E")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: { appState.currentPage = .home }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    Spacer()
                    Text("2026 年 1 月").foregroundColor(Color(hex: "CBA972"))
                    Spacer()
                    Color.clear.frame(width: 40)
                }
                .padding()

                Text("18 天")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "CBA972"), .white], startPoint: .top, endPoint: .bottom))
                    .padding()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(1...31, id: \.self) { day in
                            Circle()
                                .fill(day < 20 ? Color(hex: "CBA972").opacity(0.6) : .white.opacity(0.1))
                                .frame(width: 45, height: 45)
                                .overlay(Text("\(day)").foregroundColor(.white))
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - ========== 5. 档案 ==========
struct ArchiveView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(hex: "0A0A0F").ignoresSafeArea()

            ScrollView {
                VStack {
                    HStack {
                        Button(action: { appState.currentPage = .home }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.white.opacity(0.1)))
                        }
                        Spacer()
                        Text("生命星系").foregroundColor(Color(hex: "CBA972"))
                        Spacer()
                        Color.clear.frame(width: 40)
                    }
                    .padding()

                    ZStack {
                        Circle().fill(RadialGradient(colors: [Color(hex: "FFD700"), .clear], center: .center, startRadius: 0, endRadius: 50))
                            .frame(width: 100, height: 100)
                            .position(x: 150, y: 100)
                        Circle().fill(RadialGradient(colors: [Color(hex: "CBA972"), .clear], center: .center, startRadius: 0, endRadius: 35))
                            .frame(width: 70, height: 70)
                            .position(x: 250, y: 150)
                    }
                    .frame(height: 300)

                    VStack(spacing: 15) {
                        IdentityCard(icon: "🌅", title: "晨光捕手", desc: "连续30天早起")
                        IdentityCard(icon: "✍️", title: "文字织梦者", desc: "完成10万字创作")
                        IdentityCard(icon: "💫", title: "星辰旅人", desc: "坚持180天不离场")
                    }
                    .padding()

                    HStack(spacing: 40) {
                        VStack {
                            Text("127").font(.system(size: 36, weight: .bold)).foregroundColor(Color(hex: "CBA972"))
                            Text("完成泡泡").foregroundColor(.white.opacity(0.5))
                        }
                        VStack {
                            Text("18").font(.system(size: 36, weight: .bold)).foregroundColor(Color(hex: "CBA972"))
                            Text("里程碑").foregroundColor(.white.opacity(0.5))
                        }
                        VStack {
                            Text("89").font(.system(size: 36, weight: .bold)).foregroundColor(Color(hex: "CBA972"))
                            Text("连续天数").foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 30)
                }
            }
        }
    }
}

struct IdentityCard: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack {
            Text(icon).font(.system(size: 32))
            VStack(alignment: .leading) {
                Text(title).foregroundColor(Color(hex: "CBA972"))
                Text(desc).font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(.ultraThinMaterial))
    }
}

// MARK: - ========== 工具扩展 ==========
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
