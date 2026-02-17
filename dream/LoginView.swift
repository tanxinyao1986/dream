import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Warm cream base matching SplashView
            LinearGradient(
                colors: [Color(hex: "FFF9E6"), Color(hex: "FDFCF8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft radial glow (gold + pink, like the light orb)
            RadialGradient(
                colors: [
                    Color(hex: "FFD700").opacity(0.35),
                    Color(hex: "FFB6C1").opacity(0.2),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .opacity(pulseAnimation ? 0.7 : 0.3)
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: pulseAnimation)
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App title — localized
                VStack(spacing: 12) {
                    Text(L("微光计划"))
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .kerning(10)
                        .foregroundColor(Color(hex: "4A4A4A"))
                        .opacity(0.9)
                        .shadow(color: Color.white.opacity(0.35), radius: 10, x: 0, y: 0)

                    Text(L("每一步微光，都在凝聚力量"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "CBA972").opacity(0.75))
                }

                Spacer()

                // Sign in with Apple button
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(25)
                .padding(.horizontal, 40)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 40)
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear { pulseAnimation = true }
    }

    // MARK: - Handle Sign In Result

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let identityTokenData = appleIDCredential.identityToken,
                      let idToken = String(data: identityTokenData, encoding: .utf8),
                      let nonce = currentNonce else {
                errorMessage = L("无法获取 Apple ID 凭证")
                return
            }

            Task {
                do {
                    try await supabaseManager.signInWithApple(idToken: idToken, nonce: nonce)
                } catch {
                    await MainActor.run {
                        errorMessage = L("登录失败: %@", error.localizedDescription)
                    }
                }
            }

        case .failure(let error):
            // User cancelled is not a real error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = L("Apple 登录失败: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
