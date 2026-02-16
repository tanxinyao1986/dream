//
//  SubscriptionManager.swift
//  dream
//
//  StoreKit 2 订阅管理器 — 微光伙伴 (Free) vs 追光者 (Pro)
//

import Foundation
import StoreKit
import SwiftUI
import Combine

/// Paywall trigger context
enum PaywallContext {
    case aiMessageLimit      // 每日对话次数用完
    case archiveLocked       // 光尘档案点击
    case calendarRestricted  // 日历非当月导航
}

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    private let productIDs: Set<String> = [
        "com.lumi.pro.monthly",
        "com.lumi.pro.yearly"
    ]

    // MARK: - Published State
    @Published var isPro: Bool = false
    @Published var products: [Product] = []

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactionUpdates()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            // Sort: monthly first, yearly second
            products = storeProducts.sorted { a, b in
                (a.subscription?.subscriptionPeriod.unit == .month ? 0 : 1) <
                (b.subscription?.subscriptionPeriod.unit == .month ? 0 : 1)
            }
            // Check current entitlement
            await updateSubscriptionStatus()
        } catch {
            print("SubscriptionManager: Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Status Check

    private func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if productIDs.contains(transaction.productID) {
                    hasActiveSubscription = true
                    break
                }
            }
        }

        isPro = hasActiveSubscription
    }

    // MARK: - Transaction Updates Listener

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? await self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.updateSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
