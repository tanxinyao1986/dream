//
//  BubbleNode.swift
//  LifeBubble
//
//  SpriteKit 泡泡节点 - 物理引擎驱动的肥皂泡
//

import SpriteKit
import SwiftUI

class BubbleNode: SKShapeNode {
    let bubbleId: UUID
    let bubbleText: String
    let bubbleType: Bubble.BubbleType
    var textLabel: SKLabelNode?

    // 视觉参数
    private var iridescenceLayer: SKShapeNode?
    private var highlightLayer: SKShapeNode?

    init(bubble: Bubble, radius: CGFloat) {
        self.bubbleId = bubble.id
        self.bubbleText = bubble.text
        self.bubbleType = bubble.type

        super.init()

        // 设置形状
        let circlePath = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        self.path = circlePath

        // 基础透明填充
        self.fillColor = bubbleType == .core ?
            UIColor(Color(hex: "FFD700")).withAlphaComponent(0.25) : // 核心泡泡 - 金色基底，更高饱和度
            BubbleNode.randomMutedPastelColor().withAlphaComponent(0.12) // 琐事泡泡 - 柔和

        // 柔和边缘 - 使用渐变过渡而非硬边
        self.strokeColor = .clear
        self.lineWidth = 0

        // 物理体设置
        setupPhysicsBody(radius: radius)

        // 添加视觉层
        addIridescenceEffect(radius: radius)
        addHighlight(radius: radius)
        addTextLabel(radius: radius)

        // 添加呼吸动画
        addBreathingAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 物理引擎设置
    private func setupPhysicsBody(radius: CGFloat) {
        self.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        self.physicsBody?.isDynamic = true
        self.physicsBody?.mass = bubbleType == .core ? 1.5 : 0.8
        self.physicsBody?.friction = 0.0 // 无摩擦
        self.physicsBody?.restitution = 0.6 // 柔和弹性
        self.physicsBody?.linearDamping = 4.0 // 空气阻力 - 显著增加以极大减缓移动
        self.physicsBody?.angularDamping = 0.8 // 旋转阻尼
        self.physicsBody?.allowsRotation = false // 禁止旋转
        self.physicsBody?.categoryBitMask = 1
        self.physicsBody?.contactTestBitMask = 1
        self.physicsBody?.collisionBitMask = 1

        // 减少初始速度 - 非常缓慢的漂浮 (50% slower)
        self.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -4...4), dy: CGFloat.random(in: -4...4))
    }

    // MARK: - 视觉效果
    private func addIridescenceEffect(radius: CGFloat) {
        if bubbleType == .core {
            // 核心泡泡 - 印象派油画般的七彩光芒
            addImpressionistRainbowEffect(radius: radius)
        } else {
            // 琐事泡泡 - 柔和单色
            addSubtleColorEffect(radius: radius)
        }

        // Add irregular transparency mask at edges
        addIrregularEdgeMask(radius: radius)
    }

    // 核心泡泡 - 印象派七彩效果
    private func addImpressionistRainbowEffect(radius: CGFloat) {
        // 七彩基础色 - 高饱和度
        let vibrantColors: [UIColor] = [
            UIColor(Color(hex: "FFD700")).withAlphaComponent(0.5), // 金
            UIColor(Color(hex: "FF6B9D")).withAlphaComponent(0.5), // 玫粉
            UIColor(Color(hex: "C77DFF")).withAlphaComponent(0.5), // 亮紫
            UIColor(Color(hex: "4CC9F0")).withAlphaComponent(0.5), // 青蓝
            UIColor(Color(hex: "7FE3A0")).withAlphaComponent(0.5), // 翠绿
            UIColor(Color(hex: "FF9770")).withAlphaComponent(0.5), // 珊瑚橙
            UIColor(Color(hex: "FFE66D")).withAlphaComponent(0.5)  // 明黄
        ]

        // 创建多层渐变圆，模拟油画笔触交融
        // 第一层：大面积色块基础
        for i in 0..<7 {
            let colorLayer = SKShapeNode(circleOfRadius: radius * 0.95)
            colorLayer.fillColor = vibrantColors[i]
            colorLayer.strokeColor = .clear
            colorLayer.blendMode = .add // 颜色叠加混合
            colorLayer.zPosition = CGFloat(1 + i) * 0.1

            self.addChild(colorLayer)

            // 缓慢呼吸式的透明度变化 - 模拟光线流动
            let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 3.0 + Double(i) * 0.5)
            let fadeIn = SKAction.fadeAlpha(to: 0.5, duration: 3.0 + Double(i) * 0.5)
            let breathe = SKAction.sequence([fadeOut, fadeIn])
            colorLayer.run(SKAction.repeatForever(breathe))

            if i == 0 {
                self.iridescenceLayer = colorLayer
            }
        }

        // 第二层：中等色块 - 增加色彩深度
        for i in 0..<5 {
            let midLayer = SKShapeNode(circleOfRadius: radius * 0.7)
            midLayer.fillColor = vibrantColors[(i + 2) % vibrantColors.count]
            midLayer.strokeColor = .clear
            midLayer.blendMode = .add
            midLayer.zPosition = 1.5 + CGFloat(i) * 0.1

            self.addChild(midLayer)

            // 反向呼吸 - 创造动态交织
            let fadeOut = SKAction.fadeAlpha(to: 0.15, duration: 4.0 + Double(i) * 0.3)
            let fadeIn = SKAction.fadeAlpha(to: 0.4, duration: 4.0 + Double(i) * 0.3)
            let breathe = SKAction.sequence([fadeIn, fadeOut])
            midLayer.run(SKAction.repeatForever(breathe))
        }

        // 第三层：小范围高光色斑 - 印象派点彩效果
        for i in 0..<8 {
            let spotSize = radius * CGFloat.random(in: 0.3...0.5)
            let spotLayer = SKShapeNode(circleOfRadius: spotSize)

            // 随机位置偏移
            let angle = Double(i) * (2.0 * .pi / 8.0)
            let distance = radius * CGFloat.random(in: 0.2...0.4)
            let offsetX = cos(angle) * distance
            let offsetY = sin(angle) * distance
            spotLayer.position = CGPoint(x: offsetX, y: offsetY)

            spotLayer.fillColor = vibrantColors[i % vibrantColors.count]
            spotLayer.strokeColor = .clear
            spotLayer.blendMode = .add
            spotLayer.zPosition = 2.0 + CGFloat(i) * 0.05

            self.addChild(spotLayer)

            // 轻微的脉动
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.1, duration: 2.5),
                SKAction.fadeAlpha(to: 0.35, duration: 2.5)
            ])
            spotLayer.run(SKAction.repeatForever(pulse))
        }
    }

    // 琐事泡泡 - 柔和效果
    private func addSubtleColorEffect(radius: CGFloat) {
        // 单一柔和色调
        let subtleColor = BubbleNode.randomMutedPastelColor().withAlphaComponent(0.25)

        let colorLayer = SKShapeNode(circleOfRadius: radius * 0.9)
        colorLayer.fillColor = subtleColor
        colorLayer.strokeColor = .clear
        colorLayer.blendMode = .add
        colorLayer.zPosition = 1

        self.addChild(colorLayer)
        self.iridescenceLayer = colorLayer

        // 柔和呼吸
        let fadeOut = SKAction.fadeAlpha(to: 0.15, duration: 3.5)
        let fadeIn = SKAction.fadeAlpha(to: 0.25, duration: 3.5)
        let breathe = SKAction.sequence([fadeOut, fadeIn])
        colorLayer.run(SKAction.repeatForever(breathe))
    }

    private func addIrregularEdgeMask(radius: CGFloat) {
        // Create smooth radial gradient for natural sphere appearance
        // More layers for smoother transition from center to edge
        let layerCount = 12

        for i in 0..<layerCount {
            let progress = Double(i) / Double(layerCount)
            let ringRadius = radius * (1.0 - progress * 0.15)

            let maskRing = SKShapeNode(circleOfRadius: ringRadius)

            // Smooth gradient: brighter in center, fading toward edges
            let alpha = 0.08 * (1.0 - progress * 0.7)
            maskRing.fillColor = UIColor.white.withAlphaComponent(alpha)
            maskRing.strokeColor = .clear
            maskRing.blendMode = .add
            maskRing.zPosition = 0.5 + Double(i) * 0.01

            self.addChild(maskRing)
        }

        // Add subtle outer rim for sphere definition without harsh line
        let outerRim = SKShapeNode(circleOfRadius: radius - 1)
        outerRim.fillColor = .clear
        outerRim.strokeColor = UIColor.white.withAlphaComponent(0.15)
        outerRim.lineWidth = 1.5
        outerRim.zPosition = 0.4
        self.addChild(outerRim)
    }

    private func addHighlight(radius: CGFloat) {
        if bubbleType == .core {
            // 核心泡泡 - 多彩高光
            // 主高光 - 金白色
            let mainHighlight = SKShapeNode(circleOfRadius: radius * 0.4)
            mainHighlight.position = CGPoint(x: -radius * 0.3, y: radius * 0.3)
            mainHighlight.fillColor = UIColor(Color(hex: "FFFACD")).withAlphaComponent(0.8) // 柠檬绸色
            mainHighlight.strokeColor = .clear
            mainHighlight.zPosition = 3

            self.addChild(mainHighlight)
            self.highlightLayer = mainHighlight

            // 主高光呼吸
            let fadeOut = SKAction.fadeAlpha(to: 0.5, duration: 2.5)
            let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 2.5)
            let pulse = SKAction.sequence([fadeOut, fadeIn])
            mainHighlight.run(SKAction.repeatForever(pulse))

            // 次级彩色高光 - 增强印象派效果
            let coloredHighlight = SKShapeNode(circleOfRadius: radius * 0.25)
            coloredHighlight.position = CGPoint(x: -radius * 0.25, y: radius * 0.35)
            coloredHighlight.fillColor = UIColor(Color(hex: "FFB6C1")).withAlphaComponent(0.6) // 粉色
            coloredHighlight.strokeColor = .clear
            coloredHighlight.blendMode = .add
            coloredHighlight.zPosition = 3.1

            self.addChild(coloredHighlight)

            // 彩色高光微微脉动
            let colorPulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 3.0),
                SKAction.fadeAlpha(to: 0.6, duration: 3.0)
            ])
            coloredHighlight.run(SKAction.repeatForever(colorPulse))

        } else {
            // 琐事泡泡 - 简单白色高光
            let highlight = SKShapeNode(circleOfRadius: radius * 0.35)
            highlight.position = CGPoint(x: -radius * 0.3, y: radius * 0.3)
            highlight.fillColor = UIColor.white.withAlphaComponent(0.6)
            highlight.strokeColor = .clear
            highlight.zPosition = 3

            self.addChild(highlight)
            self.highlightLayer = highlight

            // 高光闪烁
            let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 2.5)
            let fadeIn = SKAction.fadeAlpha(to: 0.6, duration: 2.5)
            let pulse = SKAction.sequence([fadeOut, fadeIn])
            highlight.run(SKAction.repeatForever(pulse))
        }
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
        label.zPosition = 3

        self.addChild(label)
        self.textLabel = label
    }

    private func addBreathingAnimation() {
        let scaleUp = SKAction.scale(to: 1.05, duration: Double.random(in: 3...5))
        let scaleDown = SKAction.scale(to: 1.0, duration: Double.random(in: 3...5))
        let breathe = SKAction.sequence([scaleUp, scaleDown])
        self.run(SKAction.repeatForever(breathe))
    }

    // MARK: - 破裂动画
    func burst(completion: @escaping () -> Void) {
        // 停止所有动画
        self.removeAllActions()

        // 膨胀 + 淡出
        let scale = SKAction.scale(to: 1.3, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scale, fade])

        self.run(group) {
            completion()
        }
    }

    // MARK: - Muted Earth Tone Color Generator
    static func randomMutedPastelColor() -> UIColor {
        // Muted Earth Tones (Low Saturation, High Brightness)
        let mutedEarthTones: [UIColor] = [
            UIColor(Color(hex: "D6D1C8")), // Warm Gray
            UIColor(Color(hex: "E8DCC8")), // Beige
            UIColor(Color(hex: "E8E4C8")), // Pale Yellow-Gray
            UIColor(Color(hex: "E4D8CC")), // Sand
            UIColor(Color(hex: "D8CFC4")), // Muted Brown-Gray
            UIColor(Color(hex: "DCD6D0")), // Soft Taupe
            UIColor(Color(hex: "E0D8D0")), // Light Stone
            UIColor(Color(hex: "D4CEC4"))  // Greige (Gray-Beige)
        ]
        return mutedEarthTones.randomElement() ?? UIColor(Color(hex: "E8E8E8"))
    }
}
