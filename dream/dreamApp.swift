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
import Combine
import SpriteKit

// MARK: - ========== 应用入口 ==========
@main
struct dreamApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - ========== 根视图（分层导航架构）==========
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // 启动层（L1）- 最开始显示
            if appState.showSplash {
                SplashView()
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale))
            }

            // 主舞台层（L3）- 永远存在的底层
            if !appState.showSplash {
                HomeView()
                    .zIndex(0)
            }

            // 日历层（L4）- 下拉覆盖
            if appState.showCalendar {
                CalendarView()
                    .offset(y: 0)
                    .transition(.move(edge: .top))
                    .zIndex(10)
            }

            // AI对话层（L2）- 上滑覆盖
            if appState.showChat {
                ChatView()
                    .offset(y: 0)
                    .transition(.move(edge: .bottom))
                    .zIndex(20)
            }

            // 档案层（L5）- 传统推入
            if appState.showArchive {
                ArchiveView()
                    .transition(.move(edge: .trailing))
                    .zIndex(30)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.showCalendar)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.showChat)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.showArchive)
        .animation(.easeInOut(duration: 0.8), value: appState.showSplash)
    }
}

// MARK: - ========== 状态管理器 ==========
class AppState: ObservableObject {
    // 导航状态
    @Published var showSplash: Bool = true
    @Published var showCalendar: Bool = false
    @Published var showChat: Bool = false
    @Published var showArchive: Bool = false

    // 数据状态
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

    // MARK: - 导航方法
    func enterHome() {
        showSplash = false
    }

    func openCalendar() {
        showCalendar = true
    }

    func closeCalendar() {
        showCalendar = false
    }

    func openChat() {
        showChat = true
    }

    func closeChat() {
        showChat = false
    }

    func openArchive() {
        showArchive = true
    }

    func closeArchive() {
        showArchive = false
    }

    func closeAllOverlays() {
        showCalendar = false
        showChat = false
        showArchive = false
    }

    // MARK: - 数据方法
    func completeBubble(_ bubble: Bubble) {
        if let index = bubbles.firstIndex(where: { $0.id == bubble.id }) {
            bubbles.remove(at: index)
        }
    }

    func addChatMessage(_ text: String, isUser: Bool) {
        chatMessages.append(ChatMessage(text: text, isUser: isUser))
    }
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
                        withAnimation {
                            appState.enterHome()
                        }
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

// MARK: - ========== 2. 主页（中央枢纽 - SpriteKit版）==========
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var bubbleScene: BubbleScene = BubbleScene(size: CGSize(width: 430, height: 932))

    var body: some View {
        GeometryReader { geometry in
            homeContent(screenSize: geometry.size)
        }
    }

    @ViewBuilder
    private func homeContent(screenSize: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Spacer()
                    // 右上角档案入口
                    Button(action: {
                        withAnimation {
                            appState.openArchive()
                        }
                    }) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding()

                // SpriteKit 泡泡场景
                BubbleSceneView(scene: bubbleScene)

                // 底部吹气发射台
                BlowBubbleLaunchpad(bubbleScene: bubbleScene)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // 更新场景尺寸
            bubbleScene.size = screenSize

            // 计算档案入口位置（右上角星星按钮）
            // SpriteKit 坐标系：左下角是 (0,0)，所以 Y 坐标要从屏幕高度减去
            bubbleScene.archivePosition = CGPoint(
                x: screenSize.width - 40,
                y: screenSize.height - 60
            )

            // 初始化泡泡
            for bubble in appState.bubbles {
                bubbleScene.addBubble(bubble: bubble)
            }

            // 监听泡泡点击
            bubbleScene.onBubbleTapped = { bubbleId in
                // 触发粒子效果和移除
                bubbleScene.popBubble(id: bubbleId)

                // 从 AppState 中移除
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let index = appState.bubbles.firstIndex(where: { $0.id == bubbleId }) {
                        appState.bubbles.remove(at: index)
                    }
                }
            }
        }
        // 添加手势识别
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 下滑手势 → 打开日历
                    if value.translation.height > 100 {
                        withAnimation {
                            appState.openCalendar()
                        }
                    }
                    // 上滑手势 → 打开AI对话
                    else if value.translation.height < -100 {
                        withAnimation {
                            appState.openChat()
                        }
                    }
                }
        )
    }
}
// MARK: - 吹气发射台（联调 SpriteKit）
struct BlowBubbleLaunchpad: View {
    @EnvironmentObject var appState: AppState
    let bubbleScene: BubbleScene
    @State private var isBlowing = false
    @State private var blowingScale: CGFloat = 1.0
    @State private var showInputAlert = false
    @State private var newBubbleText = ""
    @State private var blowDuration: TimeInterval = 0
    @State private var blowTimer: Timer?

    var body: some View {
        ZStack {
            // 发射台底座
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "CBA972").opacity(0.2),
                            Color(hex: "CBA972").opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)

            // 吹出的泡泡（长按时显示）
            if isBlowing {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FFB6C1").opacity(0.6),
                                Color(hex: "ADD8E6").opacity(0.4),
                                Color(hex: "FFD700").opacity(0.2)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(blowingScale)
                    .animation(.easeOut(duration: 0.1), value: blowingScale)
            }

            // 提示文字
            if !isBlowing {
                Text("长按吹泡泡")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "6B6B6B").opacity(0.5))
                    .offset(y: 50)
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    if !isBlowing {
                        isBlowing = true
                        blowDuration = 0
                        blowingScale = 1.0

                        // 启动计时器，模拟吹气球逐渐变大
                        blowTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                            blowDuration += 0.05
                            if blowDuration < 2.0 {
                                blowingScale = 1.0 + (blowDuration * 0.8) // 最大到1.6倍
                            }
                        }

                        // 触觉反馈
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
                .onEnded { _ in
                    // 停止计时器
                    blowTimer?.invalidate()
                    blowTimer = nil

                    // 判断是否吹气时间足够
                    if blowDuration >= 0.5 {
                        // 吹气成功！弹出输入框
                        showInputAlert = true

                        // 触觉反馈
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }

                    // 重置状态
                    withAnimation(.easeOut(duration: 0.2)) {
                        isBlowing = false
                        blowingScale = 1.0
                    }
                    blowDuration = 0
                }
        )
        .alert("给这个泡泡起个名字", isPresented: $showInputAlert) {
            TextField("例如：整理桌面", text: $newBubbleText)
            Button("取消", role: .cancel) {
                newBubbleText = ""
            }
            Button("创建") {
                let bubbleText = newBubbleText.isEmpty ? "New Task" : newBubbleText

                // 创建新泡泡数据
                let newBubble = Bubble(
                    text: bubbleText,
                    type: .small,
                    position: CGPoint(
                        x: CGFloat.random(in: 0.2...0.8),
                        y: CGFloat.random(in: 0.3...0.7)
                    )
                )

                // 添加到 AppState
                appState.bubbles.append(newBubble)

                // 添加到 SpriteKit 场景（在屏幕中央生成）
                let centerX = bubbleScene.size.width / 2
                let centerY = bubbleScene.size.height / 2
                let randomOffset = CGFloat.random(in: -50...50)
                let spawnPosition = CGPoint(
                    x: centerX + randomOffset,
                    y: centerY + randomOffset
                )

                bubbleScene.addBubble(bubble: newBubble, at: spawnPosition)

                // 触觉反馈
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                newBubbleText = ""
            }
        }
    }
}

// MARK: - ========== 3. AI对话（上滑覆盖层）==========
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText = ""

    var body: some View {
        ZStack {
            // 半透明背景（点击关闭）
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        appState.closeChat()
                    }
                }

            VStack(spacing: 0) {
                // 拖拽手柄
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                LinearGradient(colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")], startPoint: .top, endPoint: .bottom)
                    .overlay(
                        VStack {
                            Circle()
                                .fill(RadialGradient(colors: [.white.opacity(0.9), Color(hex: "ADD8E6").opacity(0.6), Color(hex: "CBA972").opacity(0.4)], center: .center, startRadius: 0, endRadius: 90))
                                .frame(width: 160, height: 160)
                                .padding(.top, 20)

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
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        withAnimation {
                            appState.closeChat()
                        }
                    }
                }
        )
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

// MARK: - ========== 4. 日历（下拉覆盖层）==========
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    @State private var selectedDay: Int? = nil
    @State private var scaleEffect: CGFloat = 1.0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "2C2C3E"), Color(hex: "1C1C2E")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                // 拖拽手柄
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                HStack {
                    Spacer()
                    Text("2026 年 1 月").foregroundColor(Color(hex: "CBA972"))
                    Spacer()
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
                                .scaleEffect(selectedDay == day ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedDay)
                                .onTapGesture {
                                    // 触觉反馈
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()

                                    // 选中状态（视觉反馈）
                                    selectedDay = day

                                    // 打印日志
                                    print("Selected Date: 2026-01-\(day)")

                                    // 0.2秒后收起日历（回到主页）
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation {
                                            appState.closeCalendar()
                                        }
                                        selectedDay = nil
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 下滑手势 → 关闭日历（Pull Down）
                    if value.translation.height > 100 {
                        withAnimation {
                            appState.closeCalendar()
                        }
                    }
                }
        )
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
                        Button(action: {
                            withAnimation {
                                appState.closeArchive()
                            }
                        }) {
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

// MARK: - ========== SpriteKit 泡泡场景系统 ==========

/// 单个泡泡节点
class BubbleNode: SKShapeNode {
    let bubbleText: String
    let bubbleType: Bubble.BubbleType
    var bubbleId: UUID

    init(bubble: Bubble, radius: CGFloat) {
        self.bubbleText = bubble.text
        self.bubbleType = bubble.type
        self.bubbleId = bubble.id
        super.init()

        // 创建圆形
        self.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)

        // 设置颜色
        if bubble.type == .core {
            self.fillColor = UIColor(red: 1.0, green: 0.71, blue: 0.76, alpha: 0.7) // 粉色
            self.strokeColor = UIColor(red: 1.0, green: 0.71, blue: 0.76, alpha: 0.9)
        } else {
            self.fillColor = UIColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 0.6) // 灰色
            self.strokeColor = UIColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 0.8)
        }
        self.lineWidth = 2
        self.glowWidth = 5

        // 添加文字标签
        let label = SKLabelNode(text: bubbleText)
        label.fontName = "SF Pro Text"
        label.fontSize = bubble.type == .core ? 15 : 12
        label.fontColor = UIColor(red: 0.42, green: 0.42, blue: 0.42, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.preferredMaxLayoutWidth = radius * 1.6
        label.numberOfLines = 0
        label.position = .zero
        addChild(label)

        // 设置物理体
        setupPhysics(radius: radius)

        // 启动呼吸动画
        startBreathingAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPhysics(radius: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.mass = bubbleType == .core ? 2.0 : 1.0

        // 关键：取消碰撞，泡泡可以互相穿过
        body.collisionBitMask = 0
        body.categoryBitMask = 1
        body.contactTestBitMask = 0

        // 阻尼：模拟在水中的感觉
        body.linearDamping = 0.8
        body.angularDamping = 0.5

        // 初始随机速度
        let randomVelocity = CGVector(
            dx: CGFloat.random(in: -20...20),
            dy: CGFloat.random(in: -20...20)
        )
        body.velocity = randomVelocity

        self.physicsBody = body
    }

    /// 呼吸动画：永久循环的缩放
    private func startBreathingAnimation() {
        let scaleUp = SKAction.scale(to: 1.05, duration: 2.0)
        scaleUp.timingMode = .easeInEaseOut

        let scaleDown = SKAction.scale(to: 0.95, duration: 2.0)
        scaleDown.timingMode = .easeInEaseOut

        let breathe = SKAction.sequence([scaleUp, scaleDown])
        let breatheForever = SKAction.repeatForever(breathe)

        self.run(breatheForever, withKey: "breathing")
    }
}

/// 完整的泡泡场景
class BubbleScene: SKScene {
    var archivePosition: CGPoint = .zero
    var onBubbleTapped: ((UUID) -> Void)?

    override init(size: CGSize) {
        super.init(size: size)
        self.backgroundColor = .clear
        self.scaleMode = .aspectFill

        // 设置物理世界（无重力）
        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0)

        // 创建边界（防止泡泡飞出屏幕）
        setupBoundaries()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBoundaries() {
        let boundary = SKPhysicsBody(edgeLoopFrom: self.frame)
        boundary.friction = 0
        boundary.restitution = 0.3 // 轻微反弹
        self.physicsBody = boundary
    }

    /// 添加泡泡到场景
    func addBubble(bubble: Bubble, at position: CGPoint? = nil) {
        let radius: CGFloat = bubble.type == .core ? 70 : 40
        let bubbleNode = BubbleNode(bubble: bubble, radius: radius)

        // 设置位置
        if let pos = position {
            bubbleNode.position = pos
        } else {
            // 使用相对位置转换为场景坐标
            let sceneX = bubble.position.x * size.width
            let sceneY = (1.0 - bubble.position.y) * size.height // Y轴反转
            bubbleNode.position = CGPoint(x: sceneX, y: sceneY)
        }

        bubbleNode.name = bubble.id.uuidString
        addChild(bubbleNode)
    }

    /// 移除泡泡（通过ID）
    func removeBubble(id: UUID) {
        if let node = childNode(withName: id.uuidString) {
            node.removeFromParent()
        }
    }

    /// 泡泡爆裂效果：梦幻流沙归档
    func popBubble(id: UUID) {
        guard let bubbleNode = childNode(withName: id.uuidString) as? BubbleNode else { return }

        let bubblePos = bubbleNode.position
        let bubbleColor = bubbleNode.fillColor

        // 触觉反馈
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // 泡泡先缩小消失
        let shrink = SKAction.scale(to: 0, duration: 0.3)
        shrink.timingMode = .easeIn
        bubbleNode.run(shrink) {
            bubbleNode.removeFromParent()
        }

        // 生成梦幻流沙粒子
        createDreamyFlowParticles(from: bubblePos, color: bubbleColor)
    }

    /// 梦幻流沙粒子：沿弧线飞向档案入口
    private func createDreamyFlowParticles(from startPos: CGPoint, color: UIColor) {
        let particleCount = 18
        let targetPoint = archivePosition

        for i in 0..<particleCount {
            let delay = TimeInterval(i) * 0.03

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 创建圆形粒子
                let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
                particle.fillColor = color
                particle.strokeColor = color.withAlphaComponent(0.8)
                particle.lineWidth = 1
                particle.glowWidth = 3
                particle.alpha = 0.9
                particle.position = startPos

                self.addChild(particle)

                // 随机目标偏移，制造流沙感
                let randomOffsetX = CGFloat.random(in: -20...20)
                let randomOffsetY = CGFloat.random(in: -20...20)
                let finalTarget = CGPoint(
                    x: targetPoint.x + randomOffsetX,
                    y: targetPoint.y + randomOffsetY
                )

                // 创建贝塞尔曲线路径（弧线运动）
                let path = self.createArcPath(from: startPos, to: finalTarget)
                let duration = TimeInterval.random(in: 0.6...1.0)

                let followPath = SKAction.follow(path, asOffset: false, orientToPath: false, duration: duration)
                followPath.timingMode = .easeOut

                let fadeOut = SKAction.fadeOut(withDuration: duration)
                let scaleDown = SKAction.scale(to: 0.2, duration: duration)

                let group = SKAction.group([followPath, fadeOut, scaleDown])

                particle.run(group) {
                    particle.removeFromParent()
                }
            }
        }
    }

    /// 创建弧线路径（贝塞尔曲线）
    private func createArcPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)

        // 计算控制点（制造弧线效果）
        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2

        // 控制点偏移，让路径弯曲
        let offsetX = CGFloat.random(in: -50...50)
        let offsetY: CGFloat = -100 // 向上弯曲
        let controlPoint = CGPoint(x: midX + offsetX, y: midY + offsetY)

        path.addQuadCurve(to: end, control: controlPoint)

        return path
    }

    /// 处理触摸事件
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        let touchedNodes = nodes(at: location)
        for node in touchedNodes {
            if let bubbleNode = node as? BubbleNode {
                onBubbleTapped?(bubbleNode.bubbleId)
                break
            }
        }
    }
}

// MARK: - SpriteKit 视图包装器
struct BubbleSceneView: UIViewRepresentable {
    let scene: BubbleScene

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.presentScene(scene)
        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // 不需要更新
    }
}
