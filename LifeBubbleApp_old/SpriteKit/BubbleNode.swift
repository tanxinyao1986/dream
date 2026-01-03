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
            UIColor(Color(hex: "FFB6C1")).withAlphaComponent(0.15) :
            BubbleNode.randomMutedPastelColor().withAlphaComponent(0.12)

        // 边缘光晕
        self.strokeColor = UIColor.white.withAlphaComponent(0.5)
        self.lineWidth = 2
        self.glowWidth = 4

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
        self.physicsBody?.linearDamping = 2.0 // 空气阻力 - 增加以减缓移动
        self.physicsBody?.angularDamping = 0.8 // 旋转阻尼
        self.physicsBody?.allowsRotation = false // 禁止旋转
        self.physicsBody?.categoryBitMask = 1
        self.physicsBody?.contactTestBitMask = 1
        self.physicsBody?.collisionBitMask = 1

        // 减少初始速度
        self.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -20...20), dy: CGFloat.random(in: -20...20))
    }

    // MARK: - 视觉效果
    private func addIridescenceEffect(radius: CGFloat) {
        // 薄膜干涉层（通过颜色混合模拟）
        let iridescence = SKShapeNode(circleOfRadius: radius)
        iridescence.fillColor = bubbleType == .core ?
            UIColor(Color(hex: "DDA0DD")).withAlphaComponent(0.25) :
            BubbleNode.randomMutedPastelColor().withAlphaComponent(0.18)
        iridescence.strokeColor = .clear
        iridescence.blendMode = .add
        iridescence.zPosition = 1

        self.addChild(iridescence)
        self.iridescenceLayer = iridescence

        // 颜色渐变动画
        let colorSequence = bubbleType == .core ?
            [
                UIColor(Color(hex: "FFB6C1")).withAlphaComponent(0.3),
                UIColor(Color(hex: "DDA0DD")).withAlphaComponent(0.3),
                UIColor(Color(hex: "87CEEB")).withAlphaComponent(0.3),
                UIColor(Color(hex: "FFD700")).withAlphaComponent(0.3)
            ] :
            [
                BubbleNode.randomMutedPastelColor().withAlphaComponent(0.22),
                BubbleNode.randomMutedPastelColor().withAlphaComponent(0.22),
                BubbleNode.randomMutedPastelColor().withAlphaComponent(0.22)
            ]

        var colorActions: [SKAction] = []
        for color in colorSequence {
            colorActions.append(SKAction.colorize(with: color, colorBlendFactor: 1.0, duration: 3.0))
        }

        let colorCycle = SKAction.sequence(colorActions)
        iridescence.run(SKAction.repeatForever(colorCycle))
    }

    private func addHighlight(radius: CGFloat) {
        // 高光层
        let highlight = SKShapeNode(circleOfRadius: radius * 0.35)
        highlight.position = CGPoint(x: -radius * 0.3, y: radius * 0.3)
        highlight.fillColor = UIColor.white.withAlphaComponent(0.7)
        highlight.strokeColor = .clear
        highlight.zPosition = 2

        self.addChild(highlight)
        self.highlightLayer = highlight

        // 高光闪烁
        let fadeOut = SKAction.fadeAlpha(to: 0.4, duration: 2.0)
        let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 2.0)
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        highlight.run(SKAction.repeatForever(pulse))
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

    // MARK: - Muted Pastel Color Generator
    static func randomMutedPastelColor() -> UIColor {
        let mutedPastelColors: [UIColor] = [
            UIColor(Color(hex: "D4C5E2")), // Muted lavender
            UIColor(Color(hex: "C5E2D4")), // Muted mint
            UIColor(Color(hex: "E2D4C5")), // Muted peach
            UIColor(Color(hex: "D4E2E2")), // Muted powder blue
            UIColor(Color(hex: "E2C5D4")), // Muted rose
            UIColor(Color(hex: "E2E2C5")), // Muted cream
            UIColor(Color(hex: "C5D4E2")), // Muted sky blue
            UIColor(Color(hex: "E2D4D4"))  // Muted blush
        ]
        return mutedPastelColors.randomElement() ?? UIColor(Color(hex: "E8E8E8"))
    }
}
