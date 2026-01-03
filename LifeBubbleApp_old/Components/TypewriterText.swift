//
//  TypewriterText.swift
//  LifeBubble
//
//  打字机效果文字组件
//

import SwiftUI

struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    let speed: Double // 每个字符的延迟时间（秒）

    @State private var displayedText: String = ""
    @State private var currentIndex: Int = 0

    init(
        _ text: String,
        font: Font = .body,
        color: Color = .primary,
        speed: Double = 0.08
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.speed = speed
    }

    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .onAppear {
                startTyping()
            }
    }

    private func startTyping() {
        displayedText = ""
        currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText.append(text[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "FFF9E6")
            .ignoresSafeArea()

        TypewriterText(
            "今天，让我们从一个小小的愿望开始",
            font: .system(size: 20, weight: .medium),
            color: Color(hex: "CBA972"),
            speed: 0.1
        )
    }
}
