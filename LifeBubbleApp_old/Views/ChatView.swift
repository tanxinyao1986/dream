//
//  ChatView.swift
//  LifeBubble
//
//  灵感共振室 - AI对话、目标拆解
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText = ""
    @State private var pulseAnimation = false
    @State private var aiAvatarScale: CGFloat = 1.0
    @State private var isThinking = false
    @State private var showTypingIndicator = false
    @FocusState private var isInputFocused: Bool

    private let aiResponses = [
        "听起来这是一个很棒的想法！我们要不要试着把它拆解成更小的步骤？",
        "这一刻你释放了空间，真好。我们可以从最简单的部分开始。",
        "今天有点累也没关系，要不要试试从5分钟开始？",
        "我看到你的坚持了，这已经很不容易。我们可以调整一下节奏吗？",
        "这个目标听起来很有意义。让我帮你想想，第一步可以做什么？"
    ]

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color(hex: "FFF9E6"),
                    Color(hex: "FDFCF8")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 呼吸背景
            RadialGradient(
                colors: [
                    Color(hex: "FFF9E6").opacity(0.6),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .opacity(pulseAnimation ? 0.8 : 0.3)
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear { pulseAnimation = true }

            VStack(spacing: 0) {
                // 顶部导航
                HStack {
                    Button(action: {
                        appState.currentPage = .home
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.4))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // AI 母体泡泡
                ZStack {
                    // 外光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isThinking ? [
                                    Color(hex: "ADD8E6").opacity(0.7),
                                    Color(hex: "6495ED").opacity(0.3),
                                    Color.clear
                                ] : [
                                    Color(hex: "ADD8E6").opacity(0.6),
                                    Color(hex: "CBA972").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 30)

                    // AI 母体
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isThinking ? [
                                    Color.white.opacity(0.9),
                                    Color(hex: "ADD8E6").opacity(0.7),
                                    Color(hex: "6495ED").opacity(0.5),
                                    Color(hex: "4682B4").opacity(0.3)
                                ] : [
                                    Color.white.opacity(0.9),
                                    Color(hex: "ADD8E6").opacity(0.6),
                                    Color(hex: "CBA972").opacity(0.4),
                                    Color(hex: "FFB6C1").opacity(0.3)
                                ],
                                center: UnitPoint(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(0.8),
                                            Color.clear
                                        ],
                                        center: UnitPoint(x: 0.2, y: 0.2),
                                        startRadius: 0,
                                        endRadius: 50
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .offset(x: -35, y: -35)
                        )
                        .shadow(color: Color(hex: "ADD8E6").opacity(0.6), radius: 60, x: 0, y: 0)
                        .scaleEffect(aiAvatarScale)
                        .animation(.easeInOut(duration: isThinking ? 2.0 : 4.0).repeatForever(autoreverses: true), value: aiAvatarScale)
                        .onAppear {
                            aiAvatarScale = 1.05
                        }
                }
                .frame(height: 250)
                .padding(.top, 20)

                // 对话区域
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(appState.chatMessages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if showTypingIndicator {
                                TypingIndicator()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                    }
                    .onChange(of: appState.chatMessages.count) { _ in
                        if let lastMessage = appState.chatMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // 输入区域
                HStack(spacing: 10) {
                    TextField("说说你的想法...", text: $inputText)
                        .focused($isInputFocused)
                        .padding(12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.7))
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "CBA972").opacity(0.3), lineWidth: 1)
                        )

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "CBA972").opacity(0.6),
                                                Color(hex: "CBA972").opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 12, x: 0, y: 4)
                    }
                    .disabled(inputText.isEmpty)
                    .opacity(inputText.isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = inputText
        inputText = ""
        isInputFocused = false

        // 添加用户消息
        appState.addChatMessage(userMessage, isUser: true)

        // AI 思考状态
        isThinking = true
        showTypingIndicator = true

        // 模拟 AI 回复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showTypingIndicator = false

            let response = aiResponses.randomElement()!
            appState.addChatMessage(response, isUser: false)

            isThinking = false
        }
    }
}

// MARK: - 聊天气泡
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.text)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "6B6B6B"))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            message.isUser ?
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        Color(hex: "ADD8E6").opacity(0.3),
                                        Color(hex: "CBA972").opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    message.isUser ?
                                        Color(hex: "CBA972").opacity(0.3) :
                                        Color.white.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                )

            if !message.isUser { Spacer() }
        }
        .transition(.asymmetric(
            insertion: .move(edge: message.isUser ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(), value: message.id)
    }
}

// MARK: - 打字中指示器
struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(hex: "CBA972").opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(y: animationPhase == index ? -10 : 0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "ADD8E6").opacity(0.2),
                            Color(hex: "CBA972").opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // 触发动画
            animationPhase = 1
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
}
