import Foundation
import RevenueCat

enum FeslihanPlan: String, CaseIterable {
    case free
    case plus      // 30₺/month — 30 recipes + meal prep
    case pro       // 100₺/month — unlimited + meal prep

    var monthlyRecipeLimit: Int? {
        switch self {
        case .free: return 10
        case .plus: return 30
        case .pro: return nil // unlimited
        }
    }

    var canMealPrep: Bool {
        self != .free
    }

    var displayName: String {
        switch self {
        case .free: return "Ücretsiz"
        case .plus: return "Feslihan+"
        case .pro: return "Feslihan Pro"
        }
    }
}

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // TODO: Change back to .free when RevenueCat is fully set up
    @Published var currentPlan: FeslihanPlan = .pro
    @Published var recipesUsedThisMonth: Int = 0

    // RevenueCat entitlement identifiers — set these in RevenueCat dashboard
    private let proEntitlement = "feslihan_pro"
    private let plusEntitlement = "feslihan_plus"

    // Usage tracking
    private let usageKey = "feslihan_recipes_used"
    private let usageMonthKey = "feslihan_usage_month"

    private init() {
        loadUsage()
    }

    func configure() {
        Purchases.configure(
            with: .builder(withAPIKey: "appl_GjwqfROjEjlzHCgtNZxwdzawSfT")
                .build()
        )
    }

    func setUser(_ userId: String) {
        Purchases.shared.logIn(userId) { _, _, _ in }
    }

    func refreshStatus() async {
        // TODO: Remove this when RevenueCat products are live
        #if DEBUG
        return
        #endif
        do {
            let info = try await Purchases.shared.customerInfo()
            if info.entitlements[proEntitlement]?.isActive == true {
                currentPlan = .pro
            } else if info.entitlements[plusEntitlement]?.isActive == true {
                currentPlan = .plus
            } else {
                currentPlan = .free
            }
        } catch {
            print("[Subscription] Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Quota

    var canAddRecipe: Bool {
        guard let limit = currentPlan.monthlyRecipeLimit else { return true }
        return recipesUsedThisMonth < limit
    }

    var remainingRecipes: Int? {
        guard let limit = currentPlan.monthlyRecipeLimit else { return nil }
        return max(0, limit - recipesUsedThisMonth)
    }

    func recordRecipeAdded() {
        recipesUsedThisMonth += 1
        saveUsage()
    }

    private func loadUsage() {
        let currentMonth = monthKey()
        let savedMonth = UserDefaults.standard.string(forKey: usageMonthKey)
        if savedMonth == currentMonth {
            recipesUsedThisMonth = UserDefaults.standard.integer(forKey: usageKey)
        } else {
            // New month — reset counter
            recipesUsedThisMonth = 0
            saveUsage()
        }
    }

    private func saveUsage() {
        UserDefaults.standard.set(recipesUsedThisMonth, forKey: usageKey)
        UserDefaults.standard.set(monthKey(), forKey: usageMonthKey)
    }

    private func monthKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: Date())
    }
}
