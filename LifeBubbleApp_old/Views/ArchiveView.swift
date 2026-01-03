//
//  ArchiveView.swift
//  LifeBubble
//
//  内在星系 - 成就展示、身份卡片、数据光流
//

import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var appState: AppState
    @State private var nebulaPulse = false
    @State private var selectedAchievement: Achievement?
    @State private var showDetail = false

    private let achievements: [Achievement] = [
        Achievement(
            title: "完成第一本书",
            type: .major,
            date: Date(),
            description: "这是一段漫长而充实的旅程。从最初模糊的想法，到每天500字的坚持，再到最终10万字的完成。"
        ),
        Achievement(title: "30天写作习惯", type: .medium, date: Date(), description: "坚持30天的写作练习"),
        Achievement(title: "突破5万字", type: .medium, date: Date(), description: "写作里程碑达成"),
        Achievement(title: "第一篇文章", type: .small, date: Date(), description: "迈出第一步"),
        Achievement(title: "坚持一周", type: .small, date: Date(), description: "七天不间断"),
        Achievement(title: "克服拖延", type: .small, date: Date(), description: "战胜自己")
    ]

    var body: some View {
        ZStack {
            // 深空背景
            Color(hex: "0A0A0F")
                .ignoresSafeArea()

            // 星云效果
            RadialGradient(
                colors: [
                    Color(hex: "321E50").opacity(0.4),
                    Color(hex: "0A0A0F").opacity(0.8),
                    Color(hex: "0A0A0F")
                ],
                center: UnitPoint(x: 0.3, y: 0.4),
                startRadius: 0,
                endRadius: 400
            )
            .opacity(nebulaPulse ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 15).repeatForever(autoreverses: true), value: nebulaPulse)
            .onAppear { nebulaPulse = true }
            .ignoresSafeArea()

            ScrollView {
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
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                )
                        }

                        Spacer()

                        Text("生命星系")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "CBA972"))

                        Spacer()

                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // 星云容器
                    ZStack {
                        ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                            AchievementStarView(achievement: achievement, index: index)
                                .onTapGesture {
                                    selectedAchievement = achievement
                                    showDetail = true
                                }
                        }
                    }
                    .frame(height: 400)
                    .padding(.vertical, 30)

                    // 身份卡片
                    VStack(spacing: 15) {
                        IdentityCard(icon: "🌅", title: "晨光捕手", description: "连续30天早起")
                        IdentityCard(icon: "✍️", title: "文字织梦者", description: "完成10万字创作")
                        IdentityCard(icon: "💫", title: "星辰旅人", description: "坚持180天不离场")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                    // 统计面板
                    HStack(spacing: 40) {
                        StatItem(value: "127", label: "完成泡泡")
                        StatItem(value: "18", label: "里程碑")
                        StatItem(value: "89", label: "连续天数")
                    }
                    .padding(.vertical, 30)
                    .padding(.bottom, 40)
                }
            }

            // 详情弹窗
            if showDetail, let achievement = selectedAchievement {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showDetail = false
                    }

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text(achievement.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(hex: "CBA972"))

                        Spacer()

                        Button(action: {
                            showDetail = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                    }

                    Text("2025年12月15日达成")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))

                    Text(achievement.description)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(6)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "14141E").opacity(0.95),
                                    Color(hex: "0A0A0F").opacity(0.98)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                )
                .padding(.horizontal, 30)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
}

// MARK: - 成就星星视图
struct AchievementStarView: View {
    let achievement: Achievement
    let index: Int
    @State private var pulse: CGFloat = 1.0

    private var starSize: CGFloat {
        switch achievement.type {
        case .major: return 100
        case .medium: return 70
        case .small: return 45
        }
    }

    private var starColor: Color {
        switch achievement.type {
        case .major: return Color(hex: "FFD700")
        case .medium: return Color(hex: "CBA972")
        case .small: return Color(hex: "ADD8E6")
        }
    }

    private var position: (x: CGFloat, y: CGFloat) {
        let positions: [(CGFloat, CGFloat)] = [
            (0.5, 0.3),   // 中心
            (0.25, 0.4),  // 左中
            (0.7, 0.45),  // 右中
            (0.6, 0.6),   // 右下
            (0.35, 0.7),  // 左下
            (0.75, 0.65)  // 右下2
        ]
        return positions[min(index, positions.count - 1)]
    }

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            starColor.opacity(achievement.type == .major ? 1.0 : 0.9),
                            starColor.opacity(0.7),
                            starColor.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: starSize / 2
                    )
                )
                .frame(width: starSize, height: starSize)
                .shadow(color: starColor.opacity(0.8), radius: achievement.type == .major ? 60 : 40, x: 0, y: 0)
                .scaleEffect(pulse)
                .animation(
                    .easeInOut(duration: Double.random(in: 4...6))
                        .repeatForever(autoreverses: true),
                    value: pulse
                )
                .onAppear {
                    pulse = 1.1
                }
                .position(
                    x: position.x * geometry.size.width,
                    y: position.y * geometry.size.height
                )
        }
    }
}

// MARK: - 身份卡片
struct IdentityCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Text(icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "CBA972"))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "CBA972").opacity(0.2),
                            Color(hex: "ADD8E6").opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 8)
    }
}

// MARK: - 统计项
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 36, weight: .bold))
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

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

#Preview {
    ArchiveView()
        .environmentObject(AppState())
}
