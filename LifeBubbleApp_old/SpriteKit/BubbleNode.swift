//
//  BubbleNode.swift
//  LifeBubble
//
//  SpriteKit Bubble Node - Physics-driven soap bubble with SwiftUI texture rendering
//

import SpriteKit
import SwiftUI

// MARK: - SwiftUI Texture View for Bubble Rendering

struct BubbleTextureView: View {
    let type: Bubble.BubbleType
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            if type == .core {
                // Core Bubble - Rainbow iridescent orb
                coreBubbleView
            } else {
                // Chore Bubble - Soft pastel orb
                choreBubbleView
            }
        }
        .frame(width: size, height: size)
        .background(Color.clear)
    }

    // Chore Bubble - Match ChatView AI bubble (foggy/hazy)
    private var choreBubbleView: some View {
        ZStack {
            // 1. Outer glow (soft halo)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.4),
                            color.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .blur(radius: 20)

            // 2. Inner glow (foggy center)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            color.opacity(0.6),
                            color.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .blur(radius: 8)

            // 3. Glass shell (subtle edge)
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                .blur(radius: 0.5)

            // 4. Top-left highlight (reflection)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.2
                    )
                )
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: -size * 0.2, y: -size * 0.2)
                .blur(radius: 3)

            // 5. Arc highlight (curved reflection)
            Circle()
                .trim(from: 0.5, to: 0.75)
                .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(45))
                .padding(size * 0.1)
                .blur(radius: 2)
        }
    }

    // Core Bubble - Match CalendarView completed bubble (solid orb with rainbow)
    private var coreBubbleView: some View {
        ZStack {
            // 1. Outer glow (warm shadow)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "8B7355").opacity(0.5),
                            Color(hex: "8B7355").opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .blur(radius: 25)

            // 2. Base orb (solid color)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "8B7355").opacity(0.7),
                            Color(hex: "8B7355").opacity(0.4),
                            Color(hex: "8B7355").opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )

            // 3. Rainbow iridescence overlay (screen blend)
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(hex: "FFD700"),  // Gold
                            Color(hex: "FF6B9D"),  // Pink
                            Color(hex: "C77DFF"),  // Purple
                            Color(hex: "4CC9F0"),  // Blue
                            Color(hex: "7FE3A0"),  // Green
                            Color(hex: "FFD700")   // Back to gold
                        ],
                        center: .center
                    )
                )
                .opacity(0.3)
                .blendMode(.screen)
                .blur(radius: 1)

            // 4. Glass shell stroke
            Circle()
                .stroke(Color(hex: "8B7355").opacity(0.6), lineWidth: 2)

            // 5. White highlight (top-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.2, y: -size * 0.2)
                .blur(radius: 2)

            // 6. Arc highlight
            Circle()
                .trim(from: 0.5, to: 0.7)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(50))
                .padding(size * 0.12)
                .blur(radius: 1.5)
        }
    }
}

// MARK: - Bubble Node

class BubbleNode: SKNode {
    let bubbleId: UUID
    let bubbleText: String
    let bubbleType: Bubble.BubbleType
    private var spriteNode: SKSpriteNode!
    private var textLabel: SKLabelNode!

    init(bubble: Bubble, radius: CGFloat) {
        self.bubbleId = bubble.id
        self.bubbleText = bubble.text
        self.bubbleType = bubble.type

        super.init()

        // Generate texture from SwiftUI
        let texture = generateTexture(type: bubble.type, radius: radius)

        // Create sprite node with texture
        spriteNode = SKSpriteNode(texture: texture)
        spriteNode.size = CGSize(width: radius * 2, height: radius * 2)
        addChild(spriteNode)

        // Setup physics
        setupPhysicsBody(radius: radius)

        // Add text label
        addTextLabel(radius: radius)

        // Add breathing animation
        addBreathingAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Texture Generation

    private func generateTexture(type: Bubble.BubbleType, radius: CGFloat) -> SKTexture {
        let size = radius * 2

        // Select color based on type
        let color: Color
        if type == .core {
            color = Color(hex: "8B7355")  // Match calendar
        } else {
            // Random pastel colors for chore bubbles
            let pastelColors: [Color] = [
                Color(hex: "ADD8E6"),  // Light blue
                Color(hex: "FFB6C1"),  // Pink
                Color(hex: "D6D1C8"),  // Warm gray
                Color(hex: "E8DCC8"),  // Beige
                Color(hex: "CBA972")   // Gold
            ]
            color = pastelColors.randomElement()!
        }

        // Create SwiftUI view
        let bubbleView = BubbleTextureView(type: type, color: color, size: size)

        // Render to texture using ImageRenderer
        let renderer = ImageRenderer(content: bubbleView)
        renderer.scale = UIScreen.main.scale

        // Generate UIImage with transparent background
        guard let uiImage = renderer.uiImage else {
            // Fallback: simple circle texture
            return generateFallbackTexture(size: size, color: UIColor(color))
        }

        // Convert to SKTexture
        let texture = SKTexture(image: uiImage)
        texture.filteringMode = .linear

        return texture
    }

    // Fallback texture if rendering fails
    private func generateFallbackTexture(size: CGFloat, color: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        return SKTexture(image: image)
    }

    // MARK: - Physics Setup

    private func setupPhysicsBody(radius: CGFloat) {
        let physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody.isDynamic = true
        physicsBody.mass = bubbleType == .core ? 1.5 : 0.8
        physicsBody.friction = 0.0
        physicsBody.restitution = 0.6
        physicsBody.linearDamping = 2.0  // Slower movement
        physicsBody.angularDamping = 0.8
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = 1
        physicsBody.contactTestBitMask = 1
        physicsBody.collisionBitMask = 1

        // Gentle initial velocity
        physicsBody.velocity = CGVector(dx: CGFloat.random(in: -4...4), dy: CGFloat.random(in: -4...4))

        self.physicsBody = physicsBody
    }

    // MARK: - Text Label

    private func addTextLabel(radius: CGFloat) {
        textLabel = SKLabelNode(text: bubbleText)
        textLabel.fontName = "HelveticaNeue-Medium"
        textLabel.fontSize = bubbleType == .core ? 16 : 13
        textLabel.fontColor = UIColor(Color(hex: "6B6B6B"))
        textLabel.verticalAlignmentMode = .center
        textLabel.horizontalAlignmentMode = .center
        textLabel.numberOfLines = 0
        textLabel.preferredMaxLayoutWidth = radius * 1.6
        textLabel.zPosition = 10

        addChild(textLabel)
    }

    // MARK: - Breathing Animation

    private func addBreathingAnimation() {
        // Breathing scale animation
        let scaleUp = SKAction.scale(to: 1.05, duration: Double.random(in: 3...5))
        let scaleDown = SKAction.scale(to: 0.95, duration: Double.random(in: 3...5))
        let breathe = SKAction.sequence([scaleUp, scaleDown])
        spriteNode.run(SKAction.repeatForever(breathe))

        // Subtle rotation animation for core bubbles (to show iridescence)
        if bubbleType == .core {
            let rotateLeft = SKAction.rotate(byAngle: .pi / 12, duration: 4.0)
            let rotateRight = SKAction.rotate(byAngle: -.pi / 12, duration: 4.0)
            let rotate = SKAction.sequence([rotateLeft, rotateRight])
            spriteNode.run(SKAction.repeatForever(rotate))
        }

        // Gentle alpha pulsing
        let fadeOut = SKAction.fadeAlpha(to: 0.85, duration: 3.0)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 3.0)
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        spriteNode.run(SKAction.repeatForever(pulse))
    }

    // MARK: - Burst Animation

    func burst(completion: @escaping () -> Void) {
        // Stop all animations
        spriteNode.removeAllActions()

        // Scale + fade out
        let scale = SKAction.scale(to: 1.3, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scale, fade])

        spriteNode.run(group) {
            completion()
        }
    }
}

// MARK: - Color Extension (Hex Support)

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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
