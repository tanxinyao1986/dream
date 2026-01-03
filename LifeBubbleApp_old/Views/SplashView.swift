//
//  SplashView.swift
//  LifeBubble
//
//  呼吸入口 - 情绪缓冲、每日寄语
//

import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLongPressing = false
    @State private var bubbleScale: CGFloat = 1.0
    @State private var showBurstEffect = false
    @State private var pulseAnimation = false
    @State private var showQuote = false

    private let dailyMessage = "今天，让我们从一个小小的愿望开始"
    private let maxBubbleScale: CGFloat = 4.5 // 填满屏幕的比例

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
                    Color(hex: "FFF9E6").opacity(0.5),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .opacity(pulseAnimation ? 0.7 : 0.3)
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear {
                pulseAnimation = true
                // 延迟显示文字
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showQuote = true
                }
            }

            VStack(spacing: 60) {
                Spacer()

                // 中心肥皂泡光球
                ZStack {
                    // 外层光晕
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

                    // 肥皂泡主体
                    SoapBubbleView.splash(size: 220)
                        .scaleEffect(bubbleScale)
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.1)
                        .onChanged { _ in
                            startLongPress()
                        }
                        .onEnded { _ in
                            endLongPress()
                        }
                )

                Spacer()

                // 每日寄语 - 打字机效果
                if showQuote {
                    TypewriterText(
                        dailyMessage,
                        font: .system(size: 20, weight: .medium),
                        color: Color(hex: "CBA972"),
                        speed: 0.24
                    )
                    .padding(.horizontal, 40)
                }

                // 提示文字
                Text("长按光球进入")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B6B6B").opacity(0.5))
                    .opacity(isLongPressing ? 0 : 1)
                    .animation(.easeOut(duration: 0.3), value: isLongPressing)
                    .padding(.bottom, 60)
            }
            .blur(radius: showBurstEffect ? 20 : 0)
            .opacity(showBurstEffect ? 0 : 1)

            // 破裂效果
            if showBurstEffect {
                BurstTransitionView()
            }
        }
    }

    private func startLongPress() {
        guard !isLongPressing else { return }
        isLongPressing = true

        SoundManager.hapticLight()

        // 缓慢膨胀动画（模拟吹气球）
        withAnimation(.easeInOut(duration: 2.5)) {
            bubbleScale = maxBubbleScale
        }

        // 到达临界点时触发破裂
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if isLongPressing {
                triggerBurst()
            }
        }
    }

    private func endLongPress() {
        guard isLongPressing else { return }

        // 如果提前松手，泡泡恢复原状
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

        // 转场到主页
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                appState.hasCompletedSplash = true
                appState.currentPage = .home
            }
        }
    }
}

// MARK: - 破裂转场效果
struct BurstTransitionView: View {
    @State private var particles: [BurstParticle] = []
    @State private var expandingRing: CGFloat = 0

    var body: some View {
        ZStack {
            // 扩散的光环
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

            // 彩色碎片粒子
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
            Color(hex: "FFD700"), // 金
            Color(hex: "FFB6C1"), // 粉
            Color(hex: "87CEEB"), // 蓝
            Color(hex: "DDA0DD"), // 紫
            Color(hex: "FFA500")  // 橙
        ]

        // 扩散光环动画
        withAnimation(.easeOut(duration: 1.0)) {
            expandingRing = 5.0
        }

        // 生成50个碎片粒子
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

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SplashView()
        .environmentObject(AppState())
}
