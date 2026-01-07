//
//  dreamApp.swift
//  LifeBubble 梦幻肥皂泡版本 🎨
//
//  ✨ 包含 11 项 UI/UX 升级：
//  1. 肥皂泡材质渲染系统（7层叠加）
//  2. 打字机效果文字
//  3. Splash 长按膨胀 + 破裂转场
//  4. SpriteKit 物理引擎（漂浮场 + 软碰撞）
//  5. 长按发射台创建泡泡
//  6. 推迟手势（Fling to Snooze）
//  7. 贝塞尔曲线流沙粒子
//  8. Calendar 过去/未来视觉分级
//  9. Calendar Zoom In 动画
//  10. 声音管理器
//  11. 触觉反馈系统
//

import SwiftUI
import Combine
import SpriteKit
import AVFoundation

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

// MARK: - ========== 根视图 ==========
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.showSplash {
                SplashView()
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale))
            }

            if !appState.showSplash {
                HomeView()
                    .zIndex(0)
            }

            if appState.showCalendar {
                CalendarView()
                    .transition(.move(edge: .top))
                    .zIndex(10)
            }

            if appState.showChat {
                ChatView()
                    .transition(.move(edge: .bottom))
                    .zIndex(20)
            }

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
    @Published var showSplash: Bool = true
    @Published var showCalendar: Bool = false
    @Published var showChat: Bool = false
    @Published var showArchive: Bool = false

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

    func enterHome() { showSplash = false }
    func openCalendar() { showCalendar = true }
    func closeCalendar() { showCalendar = false }
    func openChat() { showChat = true }
    func closeChat() { showChat = false }
    func openArchive() { showArchive = true }
    func closeArchive() { showArchive = false }

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

// MARK: - ========== 肥皂泡材质组件 ==========
struct SoapBubbleView: View {
    let size: CGFloat
    let baseColors: [Color]
    let intensity: CGFloat

    @State private var rotationAngle: Double = 0
    @State private var highlightPhase: Double = 0

    init(size: CGFloat, baseColors: [Color], intensity: CGFloat = 0.8) {
        self.size = size
        self.baseColors = baseColors
        self.intensity = intensity
    }

    var body: some View {
        ZStack {
            // Layer 1: 透明基础（更清透 - 降低不透明度）
            Circle()
                .fill(baseColors.first?.opacity(0.02 * intensity) ?? Color.white.opacity(0.02))

            // Layer 2: 边缘光晕
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6 * intensity),
                            Color.white.opacity(0.2 * intensity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .blur(radius: 3)

            // Layer 3: 薄膜干涉（关键层 - 增强绚丽度）
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: baseColors + [baseColors.first!]),
                        center: .center,
                        angle: .degrees(rotationAngle)
                    )
                )
                .opacity(0.75 * intensity)
                .blendMode(.colorDodge)
                .blur(radius: 0.8)

            // Layer 4: 多色径向渐变
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            baseColors[0].opacity(0.3 * intensity),
                            baseColors[1].opacity(0.25 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .blendMode(.overlay)

            // Layer 5: 高光反射
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9 * intensity),
                            Color.white.opacity(0.4 * intensity),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.6, height: size * 0.6)
                .offset(x: -size * 0.15, y: -size * 0.2)
                .opacity(0.7 + 0.3 * sin(highlightPhase))

            // Layer 6: 次级高光
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.4 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.25, y: -size * 0.25)

            // Layer 7: 底部阴影
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.1 * intensity),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.85),
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
        }
        .frame(width: size, height: size)
        .shadow(
            color: baseColors.first?.opacity(0.2 * intensity) ?? Color.clear,
            radius: size * 0.15,
            x: 0,
            y: size * 0.08
        )
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                highlightPhase = .pi * 2
            }
        }
    }

    static func splash(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "FFD700"), // Gold
                Color(hex: "FF6B9D"), // Rose pink - 更饱和
                Color(hex: "C77DFF"), // Bright purple - 更饱和
                Color(hex: "4CC9F0"), // Cyan blue - 更饱和
                Color(hex: "7FE3A0"), // Emerald green - 更饱和
                Color(hex: "FF9770"), // Coral orange - 更饱和
                Color(hex: "FFE66D")  // Bright yellow - 更饱和
            ],
            intensity: 3.2  // 增强强度，让颜色更鲜艳
        )
    }

    static func core(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "FFB6C1"),
                Color(hex: "DDA0DD"),
                Color(hex: "87CEEB"),
                Color(hex: "FFD700")
            ],
            intensity: 1.0
        )
    }

    static func small(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "E0E0E0"),
                Color(hex: "B0C4DE"),
                Color(hex: "F0E68C"),
                Color(hex: "DDA0DD")
            ],
            intensity: 0.6
        )
    }
}

// MARK: - ========== 打字机效果 ==========
struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    let speed: Double

    @State private var displayedText: String = ""
    @State private var currentIndex: Int = 0

    init(_ text: String, font: Font = .body, color: Color = .primary, speed: Double = 0.16) {
        self.text = text
        self.font = font
        self.color = color
        self.speed = speed
    }

    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .onAppear {
                startTyping()
            }
    }

    private func startTyping() {
        displayedText = ""
        currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText.append(text[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - ========== 声音管理器 ==========
class SoundManager: ObservableObject {
    static let shared = SoundManager()
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    @Published var isSoundEnabled: Bool = true

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }

    func play(_ soundName: String, volume: Float = 1.0) {
        guard isSoundEnabled else { return }
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            audioPlayers[soundName] = player
        } catch {
            print("音效播放失败: \(error)")
        }
    }

    func playBubblePop() { play("pop", volume: 0.7) }
    func playBubbleCreate() { play("create", volume: 0.5) }
    func playTransition() { play("transition", volume: 0.6) }

    static func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func hapticMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func hapticHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}

// MARK: - ========== 1. Splash 页面（升级版）==========
struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLongPressing = false
    @State private var bubbleScale: CGFloat = 1.0
    @State private var showBurstEffect = false
    @State private var pulseAnimation = false
    @State private var showQuote = false

    private let dailyMessage = "Light up the little things."
    private let maxBubbleScale: CGFloat = 4.5

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "FFF9E6").opacity(0.5), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .opacity(pulseAnimation ? 0.7 : 0.3)
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear {
                pulseAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showQuote = true
                }
            }

            VStack(spacing: 60) {
                Spacer()

                // App Name: Lumi
                Text("Lumi")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(Color(hex: "CBA972"))
                    .opacity(showQuote ? 1 : 0)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(0.4),
                                    Color(hex: "FFB6C1").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .blur(radius: 30)
                        .scaleEffect(bubbleScale)

                    SoapBubbleView.splash(size: 220)
                        .scaleEffect(bubbleScale)
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.1)
                        .onChanged { _ in startLongPress() }
                        .onEnded { _ in endLongPress() }
                )

                Spacer()

                if showQuote {
                    TypewriterText(
                        dailyMessage,
                        font: .system(size: 20, weight: .medium),
                        color: Color(hex: "CBA972"),
                        speed: 0.24
                    )
                    .padding(.horizontal, 40)
                }

                Text("Long press to enter")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B6B6B").opacity(0.5))
                    .opacity(isLongPressing ? 0 : 1)
                    .padding(.bottom, 60)
            }
            .blur(radius: showBurstEffect ? 20 : 0)
            .opacity(showBurstEffect ? 0 : 1)

            if showBurstEffect {
                BurstTransitionView()
            }
        }
    }

    private func startLongPress() {
        guard !isLongPressing else { return }
        isLongPressing = true
        SoundManager.hapticLight()

        withAnimation(.easeInOut(duration: 2.5)) {
            bubbleScale = maxBubbleScale
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if isLongPressing {
                triggerBurst()
            }
        }
    }

    private func endLongPress() {
        guard isLongPressing else { return }

        if bubbleScale < maxBubbleScale {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                bubbleScale = 1.0
            }
            isLongPressing = false
        }
    }

    private func triggerBurst() {
        SoundManager.hapticHeavy()
        SoundManager.shared.playTransition()
        showBurstEffect = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                appState.enterHome()
            }
        }
    }
}

struct BurstTransitionView: View {
    @State private var particles: [BurstParticle] = []
    @State private var expandingRing: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFD700").opacity(0.8),
                            Color(hex: "FFB6C1").opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )
                .scaleEffect(expandingRing)
                .opacity(1.0 - Double(expandingRing) / 5.0)
                .blur(radius: 2)

            ForEach(particles) { particle in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                particle.color.opacity(0.9),
                                particle.color.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: particle.size * 0.5
                        )
                    )
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            generateBurstEffect()
        }
    }

    private func generateBurstEffect() {
        let center = CGPoint(
            x: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height / 2
        )

        let colors: [Color] = [
            Color(hex: "FFD700"),
            Color(hex: "FFB6C1"),
            Color(hex: "87CEEB"),
            Color(hex: "DDA0DD"),
            Color(hex: "FFA500")
        ]

        withAnimation(.easeOut(duration: 1.0)) {
            expandingRing = 5.0
        }

        for i in 0..<50 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 150...400)
            let endX = center.x + cos(angle) * distance
            let endY = center.y + sin(angle) * distance

            var particle = BurstParticle(
                position: center,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...12)
            )

            let delay = Double(i) * 0.01

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.8)) {
                    particle.position = CGPoint(x: endX, y: endY)
                    particle.opacity = 0
                }
                particles.append(particle)
            }
        }
    }
}

struct BurstParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
}

// MARK: - ========== 2. Home 页面（SpriteKit 升级版）==========
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var bubbleScene: BubbleScene = BubbleScene(size: CGSize(width: 430, height: 932))
    @State private var pulseAnimation = false
    @State private var archivePulse = false
    @State private var showingParticles = false
    @State private var isLongPressingLaunch = false
    @State private var launchBubbleScale: CGFloat = 0
    @State private var showSnoozeHint = false
    @State private var snoozeHintText = ""

    // Task input state
    @State private var showTaskInput = false
    @State private var taskInputText = ""
    @FocusState private var isTaskInputFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color(hex: "FFF9E6").opacity(0.5), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 400
                )
                .opacity(pulseAnimation ? 0.7 : 0.4)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: pulseAnimation)
                .onAppear { pulseAnimation = true }

                VStack(spacing: 0) {
                    HStack {
                        Button(action: { appState.openCalendar() }) {
                            Image(systemName: "calendar")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "6B6B6B"))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.ultraThinMaterial))
                        }

                        Spacer()

                        Button(action: { appState.openArchive() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "6B6B6B"))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    BubbleSceneView(scene: bubbleScene)

                    Spacer()
                }

                // Launchpad Button - PLACED OUTSIDE VStack WITH HIGH Z-INDEX
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color(hex: "CBA972").opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(Circle().fill(.ultraThinMaterial))
                            .frame(width: 70, height: 70)
                            .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 24, x: 0, y: 8)
                            .overlay(
                                Text("+")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(Color(hex: "CBA972").opacity(0.8))
                            )
                            .scaleEffect(isLongPressingLaunch ? 0.9 : 1.0)
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // Show task input when long press completes
                                SoundManager.hapticMedium()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showTaskInput = true
                                    isTaskInputFocused = true
                                }
                            } onPressingChanged: { pressing in
                                // Visual feedback during press
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isLongPressingLaunch = pressing
                                }
                            }

                        Text("长按吹出泡泡")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "6B6B6B").opacity(0.6))
                            .opacity(isLongPressingLaunch ? 0 : 1)
                    }
                    .padding(.bottom, 30)
                }
                .zIndex(100)  // Ensure button is on top of SpriteKit view

                // AI Chat Button (bottom-right) - Enhanced with wisdom entrance feel
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        Button(action: { appState.openChat() }) {
                            ZStack {
                                // Outer rotating light ring
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            colors: [
                                                Color(hex: "FFD700").opacity(0.8),
                                                Color(hex: "CBA972").opacity(0.6),
                                                Color(hex: "FFB6C1").opacity(0.5),
                                                Color(hex: "87CEEB").opacity(0.4),
                                                Color(hex: "FFD700").opacity(0.8)
                                            ],
                                            center: .center
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 70, height: 70)
                                    .blur(radius: 2)
                                    .rotationEffect(.degrees(archivePulse ? 360 : 0))
                                    .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: archivePulse)

                                // Pulsing glow layers
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(hex: "FFD700").opacity(0.5),
                                                Color(hex: "CBA972").opacity(0.3),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 35
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(archivePulse ? 1.3 : 1.0)
                                    .opacity(archivePulse ? 0.4 : 0.8)
                                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: archivePulse)

                                // Inner core button
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(hex: "FFD700").opacity(0.7),
                                                Color(hex: "CBA972").opacity(0.5)
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 25
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                    .shadow(color: Color(hex: "FFD700").opacity(0.6), radius: 15, x: 0, y: 0)
                                    .shadow(color: Color(hex: "CBA972").opacity(0.4), radius: 25, x: 0, y: 0)

                                // Sparkle icon with subtle scale
                                Text("✨")
                                    .font(.system(size: 22))
                                    .scaleEffect(archivePulse ? 1.05 : 0.95)
                                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: archivePulse)
                            }
                            .onAppear { archivePulse = true }
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 120)
                    }
                }

                if showSnoozeHint {
                    VStack {
                        Spacer()
                        Text(snoozeHintText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color(hex: "6B6B6B").opacity(0.9)))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 100)
                    }
                }

                // Task Input Overlay
                if showTaskInput {
                    ZStack {
                        // Semi-transparent background
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                dismissTaskInput()
                            }

                        // Input card
                        VStack(spacing: 20) {
                            Text("新建琐事")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "6B6B6B"))

                            TextField("写下你的琐事...", text: $taskInputText)
                                .focused($isTaskInputFocused)
                                .font(.system(size: 16))
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.9))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(hex: "CBA972").opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .onSubmit {
                                    createTaskBubble()
                                }

                            HStack(spacing: 12) {
                                Button(action: {
                                    dismissTaskInput()
                                }) {
                                    Text("取消")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "6B6B6B"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.7))
                                        )
                                }

                                Button(action: {
                                    createTaskBubble()
                                }) {
                                    Text("创建")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(hex: "CBA972"),
                                                            Color(hex: "CBA972").opacity(0.8)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                }
                                .disabled(taskInputText.isEmpty)
                                .opacity(taskInputText.isEmpty ? 0.5 : 1.0)
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                        .padding(.horizontal, 40)
                    }
                    .zIndex(200)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onAppear {
                bubbleScene.size = geometry.size
                bubbleScene.archivePosition = CGPoint(
                    x: geometry.size.width - 55,
                    y: geometry.size.height - 140
                )

                // Set calendar position (top-left corner, accounting for safe area and button size)
                // SpriteKit coordinates: origin at bottom-left, so we need to convert from top
                bubbleScene.calendarPosition = CGPoint(
                    x: 30,  // 20pt padding + 20pt icon center
                    y: geometry.size.height - 50  // Convert from top: total height - (20pt padding + 30pt to center)
                )

                for bubble in appState.bubbles {
                    bubbleScene.addBubble(bubble: bubble)
                }

                bubbleScene.onBubbleTapped = { bubbleId in
                    popBubble(bubbleId)
                }

                bubbleScene.onBubbleFlung = { bubbleId in
                    snoozeBubble(bubbleId)
                }
            }
        }
    }

    // MARK: - Task Input Functions
    private func dismissTaskInput() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showTaskInput = false
        }
        taskInputText = ""
        isTaskInputFocused = false
    }

    private func createTaskBubble() {
        guard !taskInputText.isEmpty else { return }

        SoundManager.hapticMedium()
        SoundManager.shared.playBubbleCreate()

        // Create new small bubble (chore type)
        let newBubble = Bubble(
            text: taskInputText,
            type: .small,
            position: CGPoint(x: 0.5, y: 0.5)  // Center position
        )

        // Add to app state
        appState.bubbles.append(newBubble)

        // Add to SpriteKit scene at center with slight randomization
        let centerX = bubbleScene.size.width / 2 + CGFloat.random(in: -30...30)
        let centerY = bubbleScene.size.height / 2 + CGFloat.random(in: -30...30)
        bubbleScene.addBubble(bubble: newBubble, at: CGPoint(x: centerX, y: centerY))

        // Dismiss input
        dismissTaskInput()
    }

    private func popBubble(_ bubbleId: UUID) {
        guard let bubble = appState.bubbles.first(where: { $0.id == bubbleId }) else { return }
        bubbleScene.popBubble(id: bubbleId)
        appState.completeBubble(bubble)
    }

    private func snoozeBubble(_ bubbleId: UUID) {
        guard let bubble = appState.bubbles.first(where: { $0.id == bubbleId }) else { return }

        snoozeHintText = "「\(bubble.text)」进入明日待办泡泡海"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSnoozeHint = true
        }

        appState.completeBubble(bubble)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSnoozeHint = false
            }
        }
    }
}

// MARK: - ========== SwiftUI to SpriteKit Snapshot Helper ==========
@available(iOS 16.0, *)
extension View {
    func renderToSKTexture(size: CGSize) -> SKTexture? {
        let renderer = ImageRenderer(content: self
            .background(Color.clear)           // CRITICAL: Transparent background
            .clipShape(Circle())                // CRITICAL: Round, not square
            .compositingGroup()                 // Preserve transparency
        )

        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = false              // CRITICAL: Enable transparency
        renderer.scale = UIScreen.main.scale   // Retina quality

        if let uiImage = renderer.uiImage {
            return SKTexture(image: uiImage)
        }
        return nil
    }
}

// MARK: - ========== SpriteKit Soap Bubble System (SwiftUI Snapshot) ==========
class BubbleNode: SKNode {
    let bubbleId: UUID
    let bubbleText: String
    let bubbleType: Bubble.BubbleType

    // Store base color for particle effects
    var baseColor: UIColor = .white

    // Visual layers
    private var bubbleSprite: SKSpriteNode!
    private var textLabel: SKLabelNode!

    init(bubble: Bubble, radius: CGFloat) {
        self.bubbleId = bubble.id
        self.bubbleText = bubble.text
        self.bubbleType = bubble.type
        super.init()

        let diameter = radius * 2

        if bubbleType == .core {
            // CORE BUBBLE: Render SplashView bubble to texture
            self.baseColor = UIColor(Color(hex: "FFD700"))
            let bubbleTexture = renderCoreBubbleTexture(size: diameter)
            createBubbleSprite(texture: bubbleTexture, size: diameter)
        } else {
            // CHORE BUBBLE: Render ChatView-style bubble to texture
            let hazyPalettes = [
                ["FFFFFF", "FFB6C1", "CBA972"],  // Pink
                ["FFFFFF", "B0E0E6", "CBA972"],  // Blue
                ["FFFFFF", "F0E68C", "D2B48C"],  // Yellow
                ["FFFFFF", "E0BBE4", "CBA972"],  // Lavender
                ["FFFFFF", "ADD8E6", "9CB4CC"]   // Light Blue
            ]
            let chosenPalette = hazyPalettes.randomElement()!
            self.baseColor = UIColor(Color(hex: chosenPalette[1]))

            let bubbleTexture = renderChoreBubbleTexture(size: diameter, colors: chosenPalette)
            createBubbleSprite(texture: bubbleTexture, size: diameter)
        }

        setupPhysicsBody(radius: radius)
        addTextLabel(radius: radius)
        addBreathingAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Snapshot Rendering
    private func renderCoreBubbleTexture(size: CGFloat) -> SKTexture? {
        if #available(iOS 16.0, *) {
            // Use EXACT SoapBubbleView.splash configuration without stroke
            let bubbleView = SoapBubbleView.splash(size: size)
            return bubbleView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            // Fallback for older iOS versions
            return renderCoreBubbleFallback(size: size)
        }
    }

    private func renderChoreBubbleTexture(size: CGFloat, colors: [String]) -> SKTexture? {
        if #available(iOS 16.0, *) {
            // Create bubble with hazy gradient (ChatView style)
            let bubbleView = createChoreBubbleView(size: size, colorHexes: colors)
            return bubbleView.renderToSKTexture(size: CGSize(width: size, height: size))
        } else {
            // Fallback for older iOS versions
            return renderChoreBubbleFallback(size: size, colors: colors)
        }
    }

    private func createChoreBubbleView(size: CGFloat, colorHexes: [String]) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: colorHexes[0]).opacity(0.9),
                        Color(hex: colorHexes[1]).opacity(0.6),
                        Color(hex: colorHexes[2]).opacity(0.4)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .shadow(color: .white.opacity(0.3), radius: 3, x: 0, y: 0)  // Soft glow instead of hard stroke
            .frame(width: size, height: size)
    }

    // Fallback for iOS < 16
    private func renderCoreBubbleFallback(size: CGFloat) -> SKTexture? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { _ in
            // Simple fallback gradient
            let colors = [
                UIColor(Color(hex: "FFD700")),
                UIColor(Color(hex: "FFA500")),
                UIColor(Color(hex: "FFB6C1"))
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors.map { $0.cgColor } as CFArray,
                                     locations: [0.0, 0.5, 1.0])!
            UIGraphicsGetCurrentContext()?.drawRadialGradient(gradient,
                                                             startCenter: CGPoint(x: size/2, y: size/2),
                                                             startRadius: 0,
                                                             endCenter: CGPoint(x: size/2, y: size/2),
                                                             endRadius: size/2,
                                                             options: [])
        }
        return SKTexture(image: image)
    }

    private func renderChoreBubbleFallback(size: CGFloat, colors: [String]) -> SKTexture? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { _ in
            let uiColors = colors.map { UIColor(Color(hex: $0)) }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: uiColors.map { $0.cgColor } as CFArray,
                                     locations: [0.0, 0.5, 1.0])!
            UIGraphicsGetCurrentContext()?.drawRadialGradient(gradient,
                                                             startCenter: CGPoint(x: size/2, y: size/2),
                                                             startRadius: 0,
                                                             endCenter: CGPoint(x: size/2, y: size/2),
                                                             endRadius: size/2,
                                                             options: [])
        }
        return SKTexture(image: image)
    }

    private func createBubbleSprite(texture: SKTexture?, size: CGFloat) {
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: size, height: size)
        sprite.zPosition = 0
        self.addChild(sprite)
        self.bubbleSprite = sprite

        // RESTORE ANIMATIONS (lost in snapshot)
        // All bubbles now use breathing animation only
        addBubblePulseAnimation(to: sprite)
    }

    // MARK: - Animation Restoration
    private func addBubblePulseAnimation(to sprite: SKSpriteNode) {
        // Breathing effect (like SplashView)
        let scaleUp = SKAction.scale(to: 1.05, duration: 3.0)
        let scaleDown = SKAction.scale(to: 0.95, duration: 3.0)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut

        let breathe = SKAction.sequence([scaleUp, scaleDown])
        sprite.run(SKAction.repeatForever(breathe), withKey: "breathe")
    }

    private func addRotationAnimation(to sprite: SKSpriteNode) {
        // Slow rotation to simulate angular gradient movement (like SplashView)
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 12.0)
        sprite.run(SKAction.repeatForever(rotate), withKey: "rotate")
    }

    // MARK: - Physics Setup
    private func setupPhysicsBody(radius: CGFloat) {
        self.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        self.physicsBody?.isDynamic = true
        self.physicsBody?.mass = bubbleType == .core ? 1.5 : 0.8
        self.physicsBody?.friction = 0.0
        self.physicsBody?.restitution = 0.6
        self.physicsBody?.linearDamping = 5.0  // Increased from 4.0 for 50% slower movement
        self.physicsBody?.angularDamping = 0.8
        self.physicsBody?.allowsRotation = false
        self.physicsBody?.categoryBitMask = 1
        self.physicsBody?.contactTestBitMask = 1
        self.physicsBody?.collisionBitMask = 1

        // 50% slower initial velocity (reduced from -8...8 to -4...4)
        self.physicsBody?.velocity = CGVector(
            dx: CGFloat.random(in: -4...4),
            dy: CGFloat.random(in: -4...4)
        )
    }

    private func addTextLabel(radius: CGFloat) {
        let label = SKLabelNode(text: bubbleText)
        label.fontName = "HelveticaNeue-Medium"
        label.fontSize = bubbleType == .core ? 16 : 13
        label.fontColor = UIColor(Color(hex: "6B6B6B"))
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = radius * 1.6
        label.zPosition = 4

        self.addChild(label)
        self.textLabel = label
    }

    private func addBreathingAnimation() {
        // Additional subtle whole-node breathing (on top of sprite pulse)
        let scaleUp = SKAction.scale(to: 1.02, duration: Double.random(in: 4...6))
        let scaleDown = SKAction.scale(to: 1.0, duration: Double.random(in: 4...6))
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let breathe = SKAction.sequence([scaleUp, scaleDown])
        self.run(SKAction.repeatForever(breathe), withKey: "nodeBreathing")
    }

    func burst(completion: @escaping () -> Void) {
        // Stop all animations
        self.removeAction(forKey: "nodeBreathing")
        bubbleSprite?.removeAction(forKey: "breathe")
        bubbleSprite?.removeAction(forKey: "rotate")

        let scale = SKAction.scale(to: 1.3, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scale, fade])

        self.run(group) {
            completion()
        }
    }
}

class BubbleScene: SKScene {
    var onBubbleTapped: ((UUID) -> Void)?
    var onBubbleFlung: ((UUID) -> Void)?
    var archivePosition: CGPoint = .zero
    var calendarPosition: CGPoint = .zero  // Left-top corner for snooze to tomorrow

    private var bubbleNodes: [UUID: BubbleNode] = [:]
    private var draggedBubble: BubbleNode?
    private var dragStartPosition: CGPoint = .zero
    private var dragStartTime: TimeInterval = 0

    override init(size: CGSize) {
        super.init(size: size)
        self.backgroundColor = .clear
        self.scaleMode = .aspectFill
        setupPhysicsWorld()
        setupFloatingFields()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPhysicsWorld() {
        physicsWorld.gravity = CGVector(dx: 0, dy: -0.05)  // Reduced by 50% for slower movement
        physicsWorld.speed = 0.75  // Reduce overall physics speed by 25%
    }

    private func setupFloatingFields() {
        // Reduce field strengths by 50% for slower movement
        let noiseField = SKFieldNode.noiseField(withSmoothness: 1.0, animationSpeed: 0.15)
        noiseField.strength = 0.075  // Reduced by 50% from 0.15
        noiseField.position = CGPoint(x: size.width / 2, y: size.height / 2)
        noiseField.region = SKRegion(size: CGSize(width: size.width * 2, height: size.height * 2))
        addChild(noiseField)

        let turbulenceField = SKFieldNode.turbulenceField(withSmoothness: 0.8, animationSpeed: 0.25)
        turbulenceField.strength = 0.04  // Reduced by 50% from 0.08
        turbulenceField.position = CGPoint(x: size.width / 2, y: size.height / 2)
        turbulenceField.region = SKRegion(size: CGSize(width: size.width * 2, height: size.height * 2))
        addChild(turbulenceField)

        // Screen edge as container - strict boundary with small inset for bubble radius
        let boundaryRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let insetBounds = boundaryRect.insetBy(dx: 20, dy: 20)  // Minimal inset to account for bubble size
        let boundary = SKPhysicsBody(edgeLoopFrom: insetBounds)
        boundary.friction = 0.0
        boundary.restitution = 0.6  // Slightly bouncy for natural container feel
        physicsBody = boundary

        // Add edge repulsion forces to keep bubbles comfortably within screen bounds
        addEdgeRepulsionFields()
    }

    private func addEdgeRepulsionFields() {
        // Create stronger repulsion fields to keep bubbles within screen container
        let edgeStrength: Float = 3.5  // Increased strength for better containment
        let edgeWidth: CGFloat = 100  // Slightly wider field

        // Left edge
        let leftField = SKFieldNode.radialGravityField()
        leftField.strength = -edgeStrength
        leftField.position = CGPoint(x: edgeWidth / 2, y: size.height / 2)
        leftField.region = SKRegion(size: CGSize(width: edgeWidth, height: size.height))
        addChild(leftField)

        // Right edge
        let rightField = SKFieldNode.radialGravityField()
        rightField.strength = -edgeStrength
        rightField.position = CGPoint(x: size.width - edgeWidth / 2, y: size.height / 2)
        rightField.region = SKRegion(size: CGSize(width: edgeWidth, height: size.height))
        addChild(rightField)

        // Top edge
        let topField = SKFieldNode.radialGravityField()
        topField.strength = -edgeStrength
        topField.position = CGPoint(x: size.width / 2, y: size.height - edgeWidth / 2)
        topField.region = SKRegion(size: CGSize(width: size.width, height: edgeWidth))
        addChild(topField)

        // Bottom edge
        let bottomField = SKFieldNode.radialGravityField()
        bottomField.strength = -edgeStrength
        bottomField.position = CGPoint(x: size.width / 2, y: edgeWidth / 2)
        bottomField.region = SKRegion(size: CGSize(width: size.width, height: edgeWidth))
        addChild(bottomField)
    }

    func addBubble(bubble: Bubble, at position: CGPoint? = nil) {
        guard bubbleNodes[bubble.id] == nil else { return }

        let radius: CGFloat = bubble.type == .core ? 80 : 45
        let bubbleNode = BubbleNode(bubble: bubble, radius: radius)

        if let pos = position {
            bubbleNode.position = pos
        } else {
            let skPosition = CGPoint(
                x: bubble.position.x * size.width,
                y: (1.0 - bubble.position.y) * size.height
            )
            bubbleNode.position = skPosition
        }

        bubbleNodes[bubble.id] = bubbleNode
        addChild(bubbleNode)
        addRepulsionField(to: bubbleNode, radius: radius)
    }

    func removeBubble(_ bubbleId: UUID, animated: Bool = true) {
        guard let node = bubbleNodes[bubbleId] else { return }

        if animated {
            node.burst {
                node.removeFromParent()
            }
        } else {
            node.removeFromParent()
        }

        bubbleNodes.removeValue(forKey: bubbleId)
    }

    func popBubble(id: UUID) {
        guard let bubbleNode = bubbleNodes[id] else { return }

        let bubblePos = bubbleNode.position
        let bubbleColor = bubbleNode.baseColor

        SoundManager.hapticMedium()
        SoundManager.shared.playBubblePop()

        bubbleNode.burst {
            bubbleNode.removeFromParent()
        }

        createDreamyFlowParticles(from: bubblePos, color: bubbleColor)
        bubbleNodes.removeValue(forKey: id)
    }

    private func addRepulsionField(to bubbleNode: BubbleNode, radius: CGFloat) {
        let repulsionField = SKFieldNode.radialGravityField()
        repulsionField.strength = -1.5
        repulsionField.falloff = 2.0
        repulsionField.region = SKRegion(radius: Float(radius * 2.0))
        repulsionField.minimumRadius = Float(radius * 1.2)
        bubbleNode.addChild(repulsionField)
    }

    private func createDreamyFlowParticles(from startPos: CGPoint, color: UIColor) {
        let particleCount = 75  // Increased by 3x (from 25 to 75)
        // Flow to bottom-right corner
        let targetPoint = CGPoint(x: size.width - 30, y: size.height - 30)

        for i in 0..<particleCount {
            let delay = TimeInterval(i) * 0.015  // 加快释放速度

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 6...12))  // Slightly larger particles
                particle.fillColor = color
                particle.strokeColor = color.withAlphaComponent(0.8)
                particle.lineWidth = 1.5
                particle.glowWidth = 5
                particle.alpha = 0.95
                particle.position = startPos

                self.addChild(particle)

                let randomOffsetX = CGFloat.random(in: -20...20)
                let randomOffsetY = CGFloat.random(in: -20...20)
                let finalTarget = CGPoint(
                    x: targetPoint.x + randomOffsetX,
                    y: targetPoint.y + randomOffsetY
                )

                let path = self.createArcPath(from: startPos, to: finalTarget)
                let duration = TimeInterval.random(in: 0.6...1.2)

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

    private func createArcPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)

        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2

        let offsetX = CGFloat.random(in: -50...50)
        let offsetY: CGFloat = -100
        let controlPoint = CGPoint(x: midX + offsetX, y: midY + offsetY)

        path.addQuadCurve(to: end, control: controlPoint)

        return path
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        let touchedNodes = nodes(at: location)
        if let bubbleNode = touchedNodes.compactMap({ $0 as? BubbleNode }).first {
            draggedBubble = bubbleNode
            dragStartPosition = location
            dragStartTime = Date().timeIntervalSince1970

            bubbleNode.physicsBody?.isDynamic = false
            SoundManager.hapticLight()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let bubble = draggedBubble else { return }

        let location = touch.location(in: self)
        bubble.position = location
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let bubble = draggedBubble else { return }

        let endPosition = touch.location(in: self)
        let endTime = Date().timeIntervalSince1970

        let dx = endPosition.x - dragStartPosition.x
        let dy = endPosition.y - dragStartPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        let duration = endTime - dragStartTime

        bubble.physicsBody?.isDynamic = true

        // Check if bubble was dragged to calendar icon (top-left corner) for snooze to tomorrow
        let distanceToCalendar = sqrt(pow(endPosition.x - calendarPosition.x, 2) +
                                     pow(endPosition.y - calendarPosition.y, 2))
        let isNearCalendar = distanceToCalendar < 100  // 100pt radius around calendar icon

        if isNearCalendar {
            // Bubble dragged to calendar - snooze to tomorrow
            SoundManager.hapticMedium()
            onBubbleFlung?(bubble.bubbleId)

            // Gentle animation toward calendar icon
            let impulse = CGVector(
                dx: (calendarPosition.x - endPosition.x) * 0.3,
                dy: (calendarPosition.y - endPosition.y) * 0.3
            )
            bubble.physicsBody?.applyImpulse(impulse)

        } else if distance < 20 && duration < 0.3 {
            // Quick tap - pop bubble
            SoundManager.hapticMedium()
            SoundManager.shared.playBubblePop()
            onBubbleTapped?(bubble.bubbleId)
        }

        draggedBubble = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let bubble = draggedBubble {
            bubble.physicsBody?.isDynamic = true
        }
        draggedBubble = nil
    }
}

struct BubbleSceneView: UIViewRepresentable {
    let scene: BubbleScene

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.presentScene(scene)
        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}

// MARK: - ========== 3. AI 对话（保留原版）==========
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText = ""
    @State private var isThinking = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.closeChat()
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                LinearGradient(colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")], startPoint: .top, endPoint: .bottom)
                    .overlay(
                        VStack {
                            // Enhanced AI Bubble with animated face
                            AIBubbleAvatar(isThinking: isThinking)
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
                        appState.closeChat()
                    }
                }
        )
    }

    func sendMessage() {
        guard !inputText.isEmpty else { return }
        appState.addChatMessage(inputText, isUser: true)
        inputText = ""

        // Show thinking animation
        isThinking = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let responses = ["这是一个很棒的想法！", "我们可以从小步开始。", "今天有点累也没关系。"]
            appState.addChatMessage(responses.randomElement()!, isUser: false)
            isThinking = false
        }
    }
}

// MARK: - ========== AI Bubble Avatar Component ==========
struct AIBubbleAvatar: View {
    let isThinking: Bool
    @State private var breatheScale: CGFloat = 1.0
    @State private var blinkAnimation = false
    @State private var mouthAnimation = false

    var body: some View {
        ZStack {
            // Bubble body with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.9),
                            Color(hex: "ADD8E6").opacity(0.6),
                            Color(hex: "CBA972").opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .scaleEffect(breatheScale)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: breatheScale)

            // Outer glow for wisdom feel
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFD700").opacity(0.4),
                            Color(hex: "ADD8E6").opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .blur(radius: 4)

            // Face elements
            VStack(spacing: 15) {
                // Eyes
                HStack(spacing: 28) {
                    // Left eye
                    EyeView(isBlinking: blinkAnimation, isThinking: isThinking)

                    // Right eye
                    EyeView(isBlinking: blinkAnimation, isThinking: isThinking)
                }
                .padding(.top, 10)

                // Mouth
                MouthView(isThinking: isThinking, animation: mouthAnimation)
                    .padding(.top, 5)
            }
        }
        .onAppear {
            breatheScale = 1.05
            // Random blink animation
            startBlinking()
            // Mouth animation
            mouthAnimation = true
        }
    }

    private func startBlinking() {
        // Blink every 3-5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 3...5)) {
            withAnimation(.easeInOut(duration: 0.15)) {
                blinkAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    blinkAnimation = false
                }
                startBlinking() // Schedule next blink
            }
        }
    }
}

// MARK: - Eye Component
struct EyeView: View {
    let isBlinking: Bool
    let isThinking: Bool

    var body: some View {
        ZStack {
            // Eye white
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: 16, height: isBlinking ? 3 : 22)
                .shadow(color: Color(hex: "ADD8E6").opacity(0.3), radius: 2)

            // Pupil
            if !isBlinking {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "4682B4"),
                                Color(hex: "1E3A5F")
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 6
                        )
                    )
                    .frame(width: 10, height: 10)
                    .offset(y: isThinking ? -2 : 0) // Look up when thinking
                    .animation(.easeInOut(duration: 0.3), value: isThinking)

                // Sparkle in eye
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: 3)
                    .offset(x: -2, y: -2)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isBlinking)
    }
}

// MARK: - Mouth Component
struct MouthView: View {
    let isThinking: Bool
    let animation: Bool

    var body: some View {
        Group {
            if isThinking {
                // Thinking mouth - small 'o' shape
                Circle()
                    .stroke(Color(hex: "CBA972").opacity(0.7), lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .scaleEffect(animation ? 1.0 : 0.9)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animation)
            } else {
                // Happy smile
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(
                        to: CGPoint(x: 30, y: 0),
                        control: CGPoint(x: 15, y: 8)
                    )
                }
                .stroke(Color(hex: "CBA972").opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 30, height: 10)
            }
        }
    }
}

// MARK: - ========== 4. 日历（升级版）==========
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let today = 1
    @State private var days: [DayData] = []

    struct DayData: Identifiable {
        let id = UUID()
        let day: Int
        let isCompleted: Bool
        let isToday: Bool
        let isFuture: Bool
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2C2C3E"), Color(hex: "1C1C2E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            StarField()

            VStack {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                HStack {
                    Button(action: { appState.closeCalendar() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    Spacer()
                    Text("2026 年 1 月")
                        .foregroundColor(Color(hex: "CBA972"))
                    Spacer()
                    Color.clear.frame(width: 40)
                }
                .padding()

                Text("18 天")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "CBA972"), .white], startPoint: .top, endPoint: .bottom))
                    .padding()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(days) { day in
                            DayRingView(day: day)
                                .onTapGesture {
                                    handleDayTap(day)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            generateDays()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        appState.closeCalendar()
                    }
                }
        )
    }

    private func generateDays() {
        days = (1...31).map { day in
            let isToday = day == today
            let isFuture = day > today
            let isCompleted = day < today && Double.random(in: 0...1) > 0.3

            return DayData(
                day: day,
                isCompleted: isCompleted,
                isToday: isToday,
                isFuture: isFuture
            )
        }
    }

    private func handleDayTap(_ day: DayData) {
        // Allow clicking today, future dates, and completed past dates
        guard day.isToday || day.isFuture || (day.isCompleted && !day.isFuture) else {
            SoundManager.hapticLight()
            return
        }

        SoundManager.hapticMedium()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {}

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.closeCalendar()
        }
    }
}

struct DayRingView: View {
    let day: CalendarView.DayData
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if day.isToday {
                ZStack {
                    SoapBubbleView(
                        size: 60,
                        baseColors: [
                            Color(hex: "FFD700"),
                            Color(hex: "FFB6C1"),
                            Color(hex: "87CEEB")
                        ],
                        intensity: 1.2
                    )
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
                    .onAppear { pulseScale = 1.08 }

                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .blur(radius: 1)
                }
                .shadow(color: Color.white.opacity(0.6), radius: 25)

            } else if day.isFuture {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "ADD8E6").opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                            )
                            .foregroundColor(Color(hex: "ADD8E6").opacity(0.25))
                            .blur(radius: 1.5)
                    )
                    .opacity(day.day <= 4 ? 0.6 : 0.25)

            } else if day.isCompleted {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "8B7355").opacity(0.5),
                                Color(hex: "8B7355").opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "8B7355").opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: Color(hex: "8B7355").opacity(0.3), radius: 12)

            } else {
                Circle()
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .opacity(0.3)
            }

            Text("\(day.day)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(
                    day.isFuture ? Color(hex: "ADD8E6").opacity(0.4) :
                    day.isToday ? .white :
                    day.isCompleted ? Color(hex: "8B7355").opacity(0.9) :
                    .white.opacity(0.25)
                )
        }
        .frame(width: 60, height: 60)
    }
}

struct StarField: View {
    @State private var stars: [Star] = []

    struct Star: Identifiable {
        let id = UUID()
        let position: CGPoint
        let size: CGFloat
        var opacity: Double
        let delay: Double
    }

    var body: some View {
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(star.position)
                    .opacity(star.opacity)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                        value: star.opacity
                    )
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        stars = (0..<100).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...1.0),
                delay: Double.random(in: 0...3)
            )
        }
    }
}

// MARK: - ========== 5. L5 "Luminous Echo" - The Sanctuary (Archive View with Atmosphere & Flashlight) ==========
struct ArchiveView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedGoal: CompletedGoal?
    @State private var showOverlay = false

    // 示例完成目标（稍后替换为 SwiftData）
    private let completedGoals: [CompletedGoal] = [
        CompletedGoal(
            title: "完成第一本小说",
            aiWitnessText: "日复一日的书写中，碎片化的想法逐渐凝聚成完整的故事。",
            season: "2024 春",
            position: CGPoint(x: 0.5, y: 0.0),
            color: Color(hex: "FFD700")
        ),
        CompletedGoal(
            title: "30天冥想之旅",
            aiWitnessText: "每个清晨的呼吸，都成为了稳定心绪的锚点，平息着思绪的波澜。",
            season: "2025 冬",
            position: CGPoint(x: 0.5, y: 0.2),
            color: Color(hex: "87CEEB")
        ),
        CompletedGoal(
            title: "学会钢琴基础",
            aiWitnessText: "手指在琴键上找到了自己的声音，将寂静转化为旋律。",
            season: "2024 秋",
            position: CGPoint(x: 0.5, y: 0.4),
            color: Color(hex: "DDA0DD")
        ),
        CompletedGoal(
            title: "阅读50本书",
            aiWitnessText: "一个个世界如同石块般堆叠，搭建起通往理解的桥梁。",
            season: "2025 夏",
            position: CGPoint(x: 0.5, y: 0.6),
            color: Color(hex: "CBA972")
        ),
        CompletedGoal(
            title: "晨间仪式",
            aiWitnessText: "黎明又黎明，微小的仪式编织出蜕变人生的织锦。",
            season: "2025 春",
            position: CGPoint(x: 0.5, y: 0.8),
            color: Color(hex: "FFB6C1")
        ),
        CompletedGoal(
            title: "健康饮食挑战",
            aiWitnessText: "每一餐的选择，都是对自己身体的温柔对话。",
            season: "2024 夏",
            position: CGPoint(x: 0.5, y: 1.0),
            color: Color(hex: "98D8C8")
        )
    ]

    // Horizontal scatter offsets for irregular layout
    private let scatterOffsets: [CGFloat] = [-80, 60, -40, 70, -60, 50]

    var body: some View {
        ZStack {
            // LAYER 1: Deep, dark background
            LinearGradient(
                colors: [
                    Color(hex: "1C1C2E"),  // Dark Navy
                    Color(hex: "14141E"),  // Deep Charcoal
                    Color(hex: "0A0A0F")   // Almost black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // LAYER 2: Visible White Fog Blobs (Backlight - Alpha 0.15)
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    VisibleBacklightFog(index: index)
                }
            }

            // LAYER 3: Ambient Stars (Bigger - Radius 2.0-3.0)
            AmbientStarsBackground()

            // LAYER 4: Scrollable List with Irregular Scatter + Enhanced Flashlight Effect
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 140) {
                    ForEach(Array(completedGoals.enumerated()), id: \.element.id) { index, goal in
                        EnhancedFlashlightLightOrb(
                            goal: goal,
                            xOffset: scatterOffsets[index % scatterOffsets.count]
                        )
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.3)) {
                                selectedGoal = goal
                                showOverlay = true
                            }
                            SoundManager.hapticLight()
                        }
                    }
                }
                .padding(.vertical, 250)  // Add padding so items can scroll to center
            }

            // LAYER 5: Navigation header (Fixed)
            VStack {
                HStack {
                    Button(action: {
                        appState.closeArchive()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }

                    Spacer()

                    Text("光之回响")
                        .font(.custom("Georgia", size: 16))
                        .italic()
                        .foregroundColor(Color(hex: "CBA972").opacity(0.8))

                    Spacer()

                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
            }

            // LAYER 6: Overlay reveal when orb is tapped
            if showOverlay, let goal = selectedGoal {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showOverlay = false
                        }
                    }

                RecallOverlay(goal: goal)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

// MARK: - Visible Backlight Fog Component (Alpha 0.15 - Acts as Backlight)
struct VisibleBacklightFog: View {
    let index: Int

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0.0

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.white)
                .frame(
                    width: CGFloat.random(in: 200...350),  // Slightly smaller
                    height: CGFloat.random(in: 200...350)
                )
                .blur(radius: CGFloat.random(in: 80...120))
                .position(position)
                .opacity(opacity)
                .blendMode(.plusLighter)  // Makes it glow like backlight
                .onAppear {
                    // Initial random position
                    position = CGPoint(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )

                    // Visible backlight - Alpha 0.15
                    withAnimation(.easeIn(duration: 4.0).delay(Double(index) * 0.4)) {
                        opacity = 0.15  // VISIBLE as backlight
                    }

                    // Slow drift
                    startDrifting(geometry: geometry)
                }
        }
    }

    private func startDrifting(geometry: GeometryProxy) {
        let duration = Double.random(in: 120...180)
        let newPosition = CGPoint(
            x: CGFloat.random(in: -80...geometry.size.width + 80),
            y: CGFloat.random(in: -80...geometry.size.height + 80)
        )

        withAnimation(.linear(duration: duration)) {
            position = newPosition
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            startDrifting(geometry: geometry)
        }
    }
}

// MARK: - Ambient Stars Background (Bigger - Radius 2.0-3.0)
struct AmbientStarsBackground: View {
    @State private var stars: [AmbientStar] = []

    var body: some View {
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(star.position)
                    .opacity(star.opacity)
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                        value: star.opacity
                    )
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        stars = (0..<80).map { _ in
            AmbientStar(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                size: CGFloat.random(in: 2.0...3.0),  // BIGGER stars (2.0-3.0)
                opacity: Double.random(in: 0.4...0.8),
                delay: Double.random(in: 0...4)
            )
        }
    }
}

struct AmbientStar: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
    let delay: Double
}

// MARK: - Enhanced Flashlight Light Orb (DRAMATIC Scaling + Irregular Scatter)
struct EnhancedFlashlightLightOrb: View {
    let goal: CompletedGoal
    let xOffset: CGFloat  // Horizontal scatter offset

    var body: some View {
        GeometryReader { geometry in
            let screenCenterY = UIScreen.main.bounds.height / 2
            let itemCenterY = geometry.frame(in: .global).midY
            let distanceFromCenter = abs(itemCenterY - screenCenterY)

            // ENHANCED DRAMATIC SCALING
            // Max scale: 1.8x (REALLY POP!)
            // Min scale: 0.6x (Much smaller)
            let scale = max(0.6, min(1.8, 1.8 - (distanceFromCenter / 300)))

            // Opacity: Fade distant items to 0.4
            let opacity = max(0.4, 1.0 - (distanceFromCenter / 350))

            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                goal.color.opacity(0.6),
                                goal.color.opacity(0.4),
                                goal.color.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 18)

                // Core light
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                goal.color.opacity(0.9),
                                goal.color.opacity(0.7)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: goal.color.opacity(0.8), radius: 25, x: 0, y: 0)
            }
            .scaleEffect(scale)  // DRAMATIC flashlight effect
            .opacity(opacity)
            .offset(x: xOffset)  // IRREGULAR SCATTER (horizontal offset)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 120)
    }
}

// MARK: - Recall Overlay Component
struct RecallOverlay: View {
    let goal: CompletedGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Goal title
            Text(goal.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // AI Witness Text (The poetic reflection)
            Text(goal.aiWitnessText)
                .font(.custom("Georgia", size: 16))
                .italic()
                .foregroundColor(Color(hex: "CBA972").opacity(0.9))
                .lineSpacing(6)
                .padding(.vertical, 8)

            // Timestamp
            Text(goal.season)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))

            Spacer()
                .frame(height: 4)
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "14141E").opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    goal.color.opacity(0.4),
                                    goal.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: goal.color.opacity(0.3), radius: 30, x: 0, y: 10)
    }
}

// MARK: - Data Model for Completed Goals
struct CompletedGoal: Identifiable {
    let id = UUID()
    let title: String
    let aiWitnessText: String
    let season: String
    let position: CGPoint
    let color: Color
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
