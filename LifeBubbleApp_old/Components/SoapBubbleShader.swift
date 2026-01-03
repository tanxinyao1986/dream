//
//  SoapBubbleShader.swift
//  LifeBubble
//
//  肥皂泡材质渲染系统 - 薄膜干涉、高光、边缘光晕
//

import SwiftUI

/// 肥皂泡材质视图 - 通用组件
struct SoapBubbleView: View {
    let size: CGFloat
    let baseColors: [Color]
    let intensity: CGFloat // 0.0-1.0, 控制效果强度

    @State private var rotationAngle: Double = 0
    @State private var highlightPhase: Double = 0

    init(
        size: CGFloat,
        baseColors: [Color] = [
            Color(hex: "FFB6C1"), // 粉色
            Color(hex: "ADD8E6"), // 蓝色
            Color(hex: "FFD700"), // 金色
            Color(hex: "DDA0DD")  // 紫色
        ],
        intensity: CGFloat = 0.8
    ) {
        self.size = size
        self.baseColors = baseColors
        self.intensity = intensity
    }

    var body: some View {
        ZStack {
            // Layer 1: 透明基础层
            Circle()
                .fill(baseColors.first?.opacity(0.02 * intensity) ?? Color.white.opacity(0.02))

            // Layer 2: 边缘光晕 (Rim Light)
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

            // Layer 3: 薄膜干涉效果 (Iridescence) - 关键层！
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: baseColors + [baseColors.first!]),
                        center: .center,
                        angle: .degrees(rotationAngle)
                    )
                )
                .opacity(0.65 * intensity)
                .blendMode(.colorDodge)
                .blur(radius: 1)

            // Layer 4: 多色径向渐变叠加
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

            // Layer 5: 高光反射 (Highlight)
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

            // Layer 6: 次级高光（增强立体感）
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

            // Layer 7: 底部阴影反光
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
            // 缓慢旋转角度渐变
            withAnimation(
                .linear(duration: 12)
                .repeatForever(autoreverses: false)
            ) {
                rotationAngle = 360
            }

            // 高光闪烁
            withAnimation(
                .easeInOut(duration: 3)
                .repeatForever(autoreverses: true)
            ) {
                highlightPhase = .pi * 2
            }
        }
    }
}

// MARK: - 预设泡泡样式

extension SoapBubbleView {
    /// 核心任务泡泡 - 梦幻粉蓝渐变
    static func core(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "FFB6C1"), // 粉
                Color(hex: "DDA0DD"), // 紫
                Color(hex: "87CEEB"), // 天蓝
                Color(hex: "FFD700")  // 金
            ],
            intensity: 1.0
        )
    }

    /// 琐事泡泡 - 柔和清新色调
    static func small(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "E0E0E0"), // 银灰
                Color(hex: "B0C4DE"), // 淡蓝
                Color(hex: "F0E68C"), // 浅黄
                Color(hex: "DDA0DD")  // 淡紫
            ],
            intensity: 0.6
        )
    }

    /// Splash 入口泡泡 - 神圣金色主题
    static func splash(size: CGFloat) -> some View {
        SoapBubbleView(
            size: size,
            baseColors: [
                Color(hex: "FFD700"), // 金
                Color(hex: "FFA500"), // 橙金
                Color(hex: "FFB6C1"), // 粉
                Color(hex: "87CEEB"), // 天蓝
                Color(hex: "DDA0DD"), // 紫
                Color(hex: "98FB98")  // 淡绿 - 增加彩虹效果
            ],
            intensity: 2.4
        )
    }
}

// MARK: - 预览
#Preview("Core Bubble") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 40) {
            SoapBubbleView.splash(size: 220)
            SoapBubbleView.core(size: 160)
            SoapBubbleView.small(size: 90)
        }
    }
}
