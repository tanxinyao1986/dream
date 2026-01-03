//
//  HomeView.swift
//  LifeBubble
//
//  当下泡泡海 - 物理交互、任务展示
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulseAnimation = false
    @State private var archivePulse = false
    @State private var showingParticles = false
    @State private var particleStartPoint: CGPoint = .zero
    @State private var particleColor: Color = .white

    // 长按发射台
    @State private var isLongPressingLaunch = false
    @State private var launchBubbleScale: CGFloat = 0
    @State private var showSnoozeHint = false
    @State private var snoozeHintText = ""

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
            .opacity(pulseAnimation ? 0.7 : 0.4)
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear { pulseAnimation = true }

            VStack(spacing: 0) {
                // 顶部导航
                HStack {
                    Button(action: {
                        appState.currentPage = .calendar
                    }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                    }

                    Spacer()

                    Button(action: {
                        appState.currentPage = .archive
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // SpriteKit 泡泡容器
                BubbleSpriteView(
                    bubbles: appState.bubbles,
                    onBubbleTapped: { bubbleId in
                        popBubble(bubbleId)
                    },
                    onBubbleFlung: { bubbleId in
                        snoozeBubble(bubbleId)
                    }
                )

                // 底部发射台
                VStack(spacing: 12) {
                    ZStack {
                        // 长按时生成的泡泡
                        if isLongPressingLaunch {
                            SoapBubbleView.core(size: launchBubbleScale)
                                .transition(.scale.combined(with: .opacity))
                        }

                        // 发射台按钮
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
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 24, x: 0, y: 8)
                            .overlay(
                                Text("+")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(Color(hex: "CBA972").opacity(0.8))
                            )
                            .scaleEffect(isLongPressingLaunch ? 0.8 : 1.0)
                    }
                    .gesture(
                        LongPressGesture(minimumDuration: 0.1)
                            .onChanged { _ in
                                startLongPressLaunch()
                            }
                            .onEnded { _ in
                                endLongPressLaunch()
                            }
                    )

                    Text("长按创建泡泡")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "6B6B6B").opacity(0.6))
                        .opacity(isLongPressingLaunch ? 0 : 1)
                }
                .padding(.bottom, 30)
            }

            // AI Chat 入口（右下角）
            VStack {
                Spacer()
                HStack {
                    Spacer()

                    Button(action: {
                        appState.currentPage = .chat
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(hex: "CBA972").opacity(0.6),
                                            Color(hex: "CBA972").opacity(0.2)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 25
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .shadow(color: Color(hex: "CBA972").opacity(0.5), radius: 20, x: 0, y: 0)
                                .scaleEffect(archivePulse ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: archivePulse)
                                .onAppear { archivePulse = true }

                            Text("✨")
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.trailing, 30)
                    .padding(.bottom, 120)
                }
            }

            // 推迟提示（甩向边缘时显示）
            if showSnoozeHint {
                VStack {
                    Spacer()
                    Text(snoozeHintText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(hex: "6B6B6B").opacity(0.9))
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
            }

            // 粒子流效果
            if showingParticles {
                BezierParticleFlow(
                    startPoint: particleStartPoint,
                    color: particleColor
                )
            }
        }
    }

    // MARK: - 长按发射台
    private func startLongPressLaunch() {
        guard !isLongPressingLaunch else { return }
        isLongPressingLaunch = true

        SoundManager.hapticLight()

        // 泡泡从小变大
        withAnimation(.easeOut(duration: 1.2)) {
            launchBubbleScale = 80
        }

        // 1.2秒后自动弹出输入框
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if isLongPressingLaunch {
                openChatInput()
            }
        }
    }

    private func endLongPressLaunch() {
        // 如果提前松手，也弹出输入框
        if isLongPressingLaunch && launchBubbleScale > 30 {
            openChatInput()
        } else {
            // 泡泡消失
            withAnimation(.easeOut(duration: 0.3)) {
                launchBubbleScale = 0
            }
        }
        isLongPressingLaunch = false
    }

    private func openChatInput() {
        SoundManager.hapticMedium()
        SoundManager.shared.playBubbleCreate()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            launchBubbleScale = 0
        }

        // TODO: Open simple "New Task" input interface (not AI Chat)
        // For now, bubble animation only - no navigation
    }

    // MARK: - 泡泡交互
    private func popBubble(_ bubbleId: UUID) {
        guard let bubble = appState.bubbles.first(where: { $0.id == bubbleId }) else { return }

        // 计算粒子起点（屏幕中心附近）
        particleStartPoint = CGPoint(
            x: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height / 2
        )
        particleColor = bubble.type == .core ? Color(hex: "FFB6C1") : Color(hex: "E8E8E8")

        // 显示粒子效果
        showingParticles = true

        // 移除泡泡
        appState.completeBubble(bubble)

        // 隐藏粒子效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingParticles = false
        }
    }

    private func snoozeBubble(_ bubbleId: UUID) {
        guard let bubble = appState.bubbles.first(where: { $0.id == bubbleId }) else { return }

        // 显示提示
        snoozeHintText = "「\(bubble.text)」进入明日待办泡泡海"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSnoozeHint = true
        }

        // TODO: 将任务日期改为明天（需要扩展数据模型）
        appState.completeBubble(bubble)

        // 隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSnoozeHint = false
            }
        }
    }
}

// MARK: - 贝塞尔粒子流效果（流沙效果）
struct BezierParticleFlow: View {
    let startPoint: CGPoint
    let color: Color
    @State private var particles: [BezierParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                particle.color.opacity(0.9),
                                particle.color.opacity(0.5),
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
                    .blur(radius: 0.5)
            }
        }
        .onAppear {
            generateBezierParticles()
        }
    }

    private func generateBezierParticles() {
        // 目标：右下角 (bottom-right corner)
        let endPoint = CGPoint(
            x: UIScreen.main.bounds.width - 30,
            y: UIScreen.main.bounds.height - 30
        )

        // 彩色粒子（从泡泡颜色派生）
        let particleColors = [
            color,
            color.opacity(0.8),
            Color.white.opacity(0.6)
        ]

        for i in 0..<75 {
            var particle = BezierParticle(
                position: startPoint,
                color: particleColors.randomElement()!,
                size: CGFloat.random(in: 4...12)
            )

            let delay = Double(i) * 0.02

            // 生成贝塞尔曲线路径
            let controlPoint1 = CGPoint(
                x: startPoint.x + CGFloat.random(in: -100...100),
                y: startPoint.y - CGFloat.random(in: 50...150)
            )
            let controlPoint2 = CGPoint(
                x: endPoint.x + CGFloat.random(in: -80...80),
                y: (startPoint.y + endPoint.y) / 2
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 使用关键帧动画模拟贝塞尔路径
                animateAlongPath(
                    particle: &particle,
                    start: startPoint,
                    control1: controlPoint1,
                    control2: controlPoint2,
                    end: endPoint,
                    duration: 1.2
                )

                particles.append(particle)
            }
        }
    }

    private func animateAlongPath(
        particle: inout BezierParticle,
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        duration: Double
    ) {
        let steps = 60
        let stepDuration = duration / Double(steps)

        for step in 0..<steps {
            let t = Double(step) / Double(steps)
            let position = cubicBezier(
                t: t,
                p0: start,
                p1: control1,
                p2: control2,
                p3: end
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                withAnimation(.linear(duration: stepDuration)) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].position = position
                        particles[index].opacity = 1.0 - t
                    }
                }
            }
        }
    }

    // 三次贝塞尔曲线公式
    private func cubicBezier(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t

        let x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
        let y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y

        return CGPoint(x: x, y: y)
    }
}

struct BezierParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
}

// MARK: - 缩放按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
