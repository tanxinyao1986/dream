import SwiftUI

enum LegalPage: Identifiable {
    case privacy
    case support

    var id: Int {
        switch self {
        case .privacy: return 1
        case .support: return 2
        }
    }

    var title: String {
        switch self {
        case .privacy: return L("隐私政策")
        case .support: return L("技术支持")
        }
    }

    var bodyText: String {
        switch self {
        case .privacy: return L("隐私政策正文")
        case .support: return L("技术支持正文")
        }
    }
}

struct LegalPageContainer: View {
    let page: LegalPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(page.bodyText)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "3C3C3C"))
                    .lineSpacing(6)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .navigationTitle(page.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("完成")) { dismiss() }
                }
            }
        }
    }
}
