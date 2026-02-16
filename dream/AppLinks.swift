import Foundation

struct AppLinks {
    private static let privacyPolicyURLZh: String = "https://tanxinyao1986.github.io/lumi/privacy.html"
    private static let technicalSupportURLZh: String = "https://tanxinyao1986.github.io/lumi/support.html"

    private static let privacyPolicyURLEn: String = "https://tanxinyao1986.github.io/lumi/privacy-en.html"
    private static let technicalSupportURLEn: String = "https://tanxinyao1986.github.io/lumi/support-en.html"

    private static var isChineseLocale: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("zh") ?? false
    }

    static var privacyPolicyURL: URL? {
        URL(string: isChineseLocale ? privacyPolicyURLZh : privacyPolicyURLEn)
    }

    static var technicalSupportURL: URL? {
        URL(string: isChineseLocale ? technicalSupportURLZh : technicalSupportURLEn)
    }
}
