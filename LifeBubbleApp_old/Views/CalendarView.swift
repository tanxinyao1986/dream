//
//  CalendarView.swift
//  LifeBubble
//
//  生命星图 - 月度视图、时光回顾
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @State private var days: [DayData] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 7)
    private let today = 1 // 假设今天是1号

    var body: some View {
        ZStack {
            // 深色背景
            LinearGradient(
                colors: [
                    Color(hex: "2C2C3E"),
                    Color(hex: "1C1C2E")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 星空背景
            StarField()

            VStack(spacing: 0) {
                // 顶部导航
                HStack {
                    Button(action: {
                        appState.currentPage = .home
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }

                    Spacer()

                    Text("2026 年 1 月")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "CBA972"))

                    Spacer()

                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 月度总览
                VStack(spacing: 10) {
                    Text("这个月你的光芒")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))

                    Text("18 天")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "CBA972"),
                                    Color.white.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.vertical, 30)

                // 日历网格
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(days) { day in
                            DayRingView(day: day)
                                .onTapGesture {
                                    handleDayTap(day)
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            generateDays()
        }
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
        // 允许点击今天、已完成的过去日期、以及未来日期
        guard day.isToday || day.isFuture || (day.isCompleted && !day.isFuture) else {
            // 未完成的过去日期，轻微震动提示
            SoundManager.hapticLight()
            return
        }

        // 触觉反馈
        SoundManager.hapticMedium()

        // Zoom In 动画后跳转
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            // 这里可以添加全局缩放效果
        }

        // 延迟跳转到对应日期的泡泡海
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.currentPage = .home
        }
    }
}

// MARK: - 日期圆环视图
struct DayRingView: View {
    let day: DayData
    @State private var pulseScale: CGFloat = 1.0
    @State private var isZooming = false
    @Namespace private var bubbleAnimation

    var body: some View {
        ZStack {
            if day.isToday {
                // 今天 - 明亮脉动肥皂泡
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

                    // 外圈光晕
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .blur(radius: 1)
                }
                .shadow(color: Color.white.opacity(0.6), radius: 25, x: 0, y: 0)

            } else if day.isFuture {
                // 未来 - 幽灵泡泡（模糊边缘）
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
                // 过去 - 已完成（降低饱和度）
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "8B7355").opacity(0.5), // 褪色的金色
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
                    .shadow(color: Color(hex: "8B7355").opacity(0.3), radius: 12, x: 0, y: 0)

            } else {
                // 过去 - 未完成（极低可见度）
                Circle()
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .opacity(0.3)
            }

            // 日期数字
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
        .scaleEffect(isZooming ? 10 : 1)
        .opacity(isZooming ? 0 : 1)
    }

    func zoom(to action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isZooming = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            action()
        }
    }
}

// MARK: - 星空背景
struct StarField: View {
    @State private var stars: [Star] = []

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

struct Star: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    var opacity: Double
    let delay: Double
}

#Preview {
    CalendarView()
        .environmentObject(AppState())
}
