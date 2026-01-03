//
//  BubbleScene.swift
//  LifeBubble
//
//  泡泡物理场景 - 漂浮场、软碰撞、手势交互
//

import SpriteKit
import SwiftUI

class BubbleScene: SKScene {
    // 回调闭包
    var onBubbleTapped: ((UUID) -> Void)?
    var onBubbleFlung: ((UUID) -> Void)?

    // 泡泡节点映射
    private var bubbleNodes: [UUID: BubbleNode] = [:]

    // 手势追踪
    private var draggedBubble: BubbleNode?
    private var dragStartPosition: CGPoint = .zero
    private var dragStartTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        setupPhysicsWorld()
        setupFloatingFields()
    }

    // MARK: - 物理世界设置
    private func setupPhysicsWorld() {
        // 几乎零重力（泡泡漂浮感）
        physicsWorld.gravity = CGVector(dx: 0, dy: -0.2)
        physicsWorld.speed = 1.0
    }

    // MARK: - 漂浮场设置
    private func setupFloatingFields() {
        // 噪声场 - 模拟空气流动
        let noiseField = SKFieldNode.noiseField(withSmoothness: 1.0, animationSpeed: 0.5)
        noiseField.strength = 0.3
        noiseField.position = CGPoint(x: size.width / 2, y: size.height / 2)
        noiseField.region = SKRegion(size: CGSize(width: size.width * 2, height: size.height * 2))
        addChild(noiseField)

        // 湍流场 - 增加随机性
        let turbulenceField = SKFieldNode.turbulenceField(withSmoothness: 0.8, animationSpeed: 0.8)
        turbulenceField.strength = 0.15
        turbulenceField.position = CGPoint(x: size.width / 2, y: size.height / 2)
        turbulenceField.region = SKRegion(size: CGSize(width: size.width * 2, height: size.height * 2))
        addChild(turbulenceField)

        // 边界软反弹（防止泡泡飞出屏幕）
        // 确保边界与屏幕完全匹配
        let boundaryRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let boundary = SKPhysicsBody(edgeLoopFrom: boundaryRect)
        boundary.friction = 0.0
        boundary.restitution = 0.5
        physicsBody = boundary
    }

    // MARK: - 泡泡管理
    func addBubble(_ bubble: Bubble) {
        guard bubbleNodes[bubble.id] == nil else { return }

        let radius: CGFloat = bubble.type == .core ? 80 : 45
        let bubbleNode = BubbleNode(bubble: bubble, radius: radius)

        // 转换位置（SwiftUI坐标 -> SpriteKit坐标）
        let skPosition = CGPoint(
            x: bubble.position.x * size.width,
            y: (1.0 - bubble.position.y) * size.height
        )
        bubbleNode.position = skPosition

        bubbleNodes[bubble.id] = bubbleNode
        addChild(bubbleNode)

        // 添加软碰撞（磁场排斥力）
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

    func updateBubbles(_ bubbles: [Bubble]) {
        // 移除不存在的泡泡
        let currentIds = Set(bubbles.map { $0.id })
        let nodeIds = Set(bubbleNodes.keys)
        let toRemove = nodeIds.subtracting(currentIds)

        for id in toRemove {
            removeBubble(id, animated: false)
        }

        // 添加新泡泡
        for bubble in bubbles {
            if bubbleNodes[bubble.id] == nil {
                addBubble(bubble)
            }
        }
    }

    // MARK: - 软碰撞（排斥力场）
    private func addRepulsionField(to bubbleNode: BubbleNode, radius: CGFloat) {
        let repulsionField = SKFieldNode.radialGravityField()
        repulsionField.strength = -1.5 // 负值 = 排斥
        repulsionField.falloff = 2.0
        repulsionField.region = SKRegion(radius: Float(radius * 2.0))
        repulsionField.minimumRadius = Float(radius * 1.2)

        bubbleNode.addChild(repulsionField)
    }

    // MARK: - 触摸处理
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // 查找被触摸的泡泡
        let touchedNodes = nodes(at: location)
        if let bubbleNode = touchedNodes.compactMap({ $0 as? BubbleNode }).first {
            draggedBubble = bubbleNode
            dragStartPosition = location
            dragStartTime = Date().timeIntervalSince1970

            // 锁定物理体（防止在拖拽时受力场影响）
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

        // 计算速度和距离
        let dx = endPosition.x - dragStartPosition.x
        let dy = endPosition.y - dragStartPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        let duration = endTime - dragStartTime
        let velocity = duration > 0 ? distance / CGFloat(duration) : 0

        // 恢复物理体
        bubble.physicsBody?.isDynamic = true

        // 判断是否是"推迟"手势（快速甩向边缘）
        let isFlingGesture = velocity > 800 && distance > 100

        if isFlingGesture {
            // 推迟手势 - 飞向边缘
            SoundManager.hapticMedium()
            onBubbleFlung?(bubble.bubbleId)

            // 施加冲量
            let impulse = CGVector(dx: dx * 0.5, dy: dy * 0.5)
            bubble.physicsBody?.applyImpulse(impulse)

        } else if distance < 20 && duration < 0.3 {
            // 点击手势 - 戳破
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
