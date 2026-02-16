//
//  PaywallView.swift
//  dream
//
//  温暖风格付费墙 — 追光者 Pro
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    let context: PaywallContext
    let onDismiss: () -> Void

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var activeLegalPage: LegalPage?

    // Context-dependent copy
    private var title: String {
        switch context {
        case .aiMessageLimit:
            return L("今天的对话次数已用完")
        case .archiveLocked:
            return L("微光正在汇聚成河")
        case .calendarRestricted:
            return L("解锁时间视野")
        }
    }

    private var subtitle: String {
        switch context {
        case .aiMessageLimit:
            return L("升级追光者，与微光无限畅聊")
        case .archiveLocked:
            return L("升级追光者，一路见证自己的成长")
        case .calendarRestricted:
            return L("回顾来路，看清远方")
        }
    }

    var body: some View {
        ZStack {
            // Warm gradient background
            LinearGradient(
                colors: [
                    Color(hex: "FFF9E6"),
                    Color(hex: "FFF3D0"),
                    Color(hex: "FDFCF8")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "8B7355").opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(hex: "8B7355").opacity(0.08))
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // MARK: - Header
                    VStack(spacing: 10) {
                        // Glow icon
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "CBA972"))
                            .shadow(color: Color(hex: "CBA972").opacity(0.4), radius: 12)

                        Text(title)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Color(hex: "4A3728"))

                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "8B7355"))
                    }

                    // MARK: - Benefits Comparison
                    benefitsTable

                    if subscriptionManager.products.isEmpty {
                        // Products not yet loaded
                        productsLoadingView
                    } else {
                        // MARK: - Product Cards
                        productCards

                        // MARK: - Purchase Button
                        purchaseButton
                    }

                    // MARK: - Restore
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isPro {
                                onDismiss()
                            }
                        }
                    }) {
                        Text(L("恢复订阅"))
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8B7355").opacity(0.7))
                    }

                    // MARK: - Legal Links
                    VStack(spacing: 6) {
                        Text(L("购买即表示你已阅读并同意以下内容"))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8B7355").opacity(0.7))

                        HStack(spacing: 16) {
                            Button(L("隐私政策")) {
                                activeLegalPage = .privacy
                            }
                            Button(L("技术支持")) {
                                activeLegalPage = .support
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "8B7355"))
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 24)
            }
            } // end VStack
        }
        .alert(L("购买失败"), isPresented: $showError) {
            Button(L("好的"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $activeLegalPage) { page in
            LegalPageContainer(page: page)
        }
        .onAppear {
            // Default select yearly
            selectedProduct = subscriptionManager.products.last
        }
        .task {
            // Retry loading if products are empty
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
                selectedProduct = subscriptionManager.products.last
            }
        }
    }

    // MARK: - Benefits Table

    private var benefitsTable: some View {
        VStack(spacing: 0) {
            benefitRow(
                icon: "bubble.left.fill",
                feature: L("AI 陪伴"),
                free: L("8条/天"),
                pro: L("无限畅聊"),
                isFirst: true
            )
            benefitRow(
                icon: "sparkle",
                feature: L("光尘档案"),
                free: L("光球可见"),
                pro: L("完整阅读")
            )
            benefitRow(
                icon: "calendar",
                feature: L("日历视野"),
                free: L("仅当月"),
                pro: L("全部")
            )
            benefitRow(
                icon: "scope",
                feature: L("愿景数量"),
                free: L("专注一个"),
                pro: L("专注一个"),
                isLast: true,
                note: L("专注是一种力量")
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.6))
                .shadow(color: Color(hex: "CBA972").opacity(0.08), radius: 12, y: 4)
        )
    }

    private func benefitRow(
        icon: String,
        feature: String,
        free: String,
        pro: String,
        isFirst: Bool = false,
        isLast: Bool = false,
        note: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "CBA972"))
                    .frame(width: 24)

                Text(feature)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "4A3728"))

                Spacer()

                Text(free)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8B7355").opacity(0.6))
                    .frame(width: 70, alignment: .center)

                Text(pro)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "CBA972"))
                    .frame(width: 70, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if let note = note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8B7355").opacity(0.5))
                    .italic()
                    .padding(.bottom, 8)
            }

            if !isLast {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Product Cards

    private var productCards: some View {
        HStack(spacing: 12) {
            ForEach(subscriptionManager.products, id: \.id) { product in
                let isMonthly = product.subscription?.subscriptionPeriod.unit == .month
                let isSelected = selectedProduct?.id == product.id

                Button(action: {
                    selectedProduct = product
                    SoundManager.hapticLight()
                }) {
                    VStack(spacing: 8) {
                        if !isMonthly {
                            Text(L("省17%"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "CBA972"))
                                )
                        } else {
                            Spacer().frame(height: 20)
                        }

                        Text(isMonthly ? L("月度") : L("年度"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "4A3728"))

                        Text(product.displayPrice)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "4A3728"))

                        Text(isMonthly ? L("/月") : L("/年"))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8B7355").opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color(hex: "FFF9E6") : Color.white.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        isSelected ? Color(hex: "CBA972") : Color(hex: "8B7355").opacity(0.15),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .shadow(color: isSelected ? Color(hex: "CBA972").opacity(0.15) : .clear, radius: 8, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button(action: {
            guard let product = selectedProduct else { return }
            isPurchasing = true
            Task {
                do {
                    let success = try await subscriptionManager.purchase(product)
                    isPurchasing = false
                    if success {
                        onDismiss()
                    }
                } catch {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }) {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                    Text(L("开始追光"))
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "CBA972"), Color(hex: "B8963E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(hex: "CBA972").opacity(0.3), radius: 12, y: 4)
            )
        }
        .disabled(selectedProduct == nil || isPurchasing)
        .opacity(selectedProduct == nil ? 0.5 : 1)
    }

    // MARK: - Product Loading State

    /// Shown when products haven't loaded yet
    private var productsLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color(hex: "CBA972"))
            Text(L("正在加载商品信息..."))
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "8B7355").opacity(0.6))
        }
        .frame(height: 100)
    }
}
