import Foundation

struct AppLinks {
    // TODO: Replace with Supabase Pages URLs after deployment.
    static let privacyPolicyURLString: String = "https://tanxinyao1986.github.io/lumi/privacy.html"
    static let technicalSupportURLString: String = "https://tanxinyao1986.github.io/lumi/support.html"

    static var privacyPolicyURL: URL? {
        URL(string: privacyPolicyURLString)
    }

    static var technicalSupportURL: URL? {
        URL(string: technicalSupportURLString)
    }
}
