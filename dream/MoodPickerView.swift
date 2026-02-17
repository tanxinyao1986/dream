import SwiftUI

struct MoodPickerView: View {
    let onMoodSelected: (String) -> Void

    private let moods: [(emoji: String, label: String, value: String)] = [
        ("🌟", L("很好"), "great"),
        ("😊", L("不错"), "good"),
        ("😐", L("一般"), "okay"),
        ("😔", L("低落"), "bad")
    ]

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Card
            VStack(spacing: 20) {
                Text(L("今天感觉怎么样？"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    ForEach(moods, id: \.value) { mood in
                        Button {
                            onMoodSelected(mood.value)
                        } label: {
                            VStack(spacing: 6) {
                                Text(mood.emoji)
                                    .font(.system(size: 36))
                                Text(mood.label)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 64, height: 72)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}
