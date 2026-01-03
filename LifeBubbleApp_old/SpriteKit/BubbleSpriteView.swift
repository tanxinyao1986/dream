//
//  BubbleSpriteView.swift
//  LifeBubble
//
//  SpriteKit 场景的 SwiftUI 包装器
//

import SwiftUI
import SpriteKit

struct BubbleSpriteView: UIViewRepresentable {
    let bubbles: [Bubble]
    let onBubbleTapped: (UUID) -> Void
    let onBubbleFlung: (UUID) -> Void

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true

        // 性能优化
        skView.showsFPS = false
        skView.showsNodeCount = false

        // 创建场景
        let scene = BubbleScene()
        scene.size = UIScreen.main.bounds.size
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.onBubbleTapped = onBubbleTapped
        scene.onBubbleFlung = onBubbleFlung

        skView.presentScene(scene)

        // 初始化泡泡
        scene.updateBubbles(bubbles)

        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        guard let scene = uiView.scene as? BubbleScene else { return }
        scene.updateBubbles(bubbles)
    }
}
