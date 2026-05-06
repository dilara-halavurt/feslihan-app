import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscription = SubscriptionService.shared
    @State private var offerings: Offerings?
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(DS.ember)

                            Text("Feslihan'ı Yükselt")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.ink)

                            Text("Daha fazla tarif, haftalık yemek planı ve daha fazlası")
                                .font(.system(size: 15))
                                .foregroundStyle(DS.smoke)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Current plan badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(DS.ember)
                                .frame(width: 8, height: 8)
                            Text("Mevcut plan: \(subscription.currentPlan.displayName)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.smoke)
                        }

                        // Plan cards
                        VStack(spacing: 12) {
                            planCard(
                                name: "Feslihan+",
                                price: "₺30/ay",
                                features: [
                                    "Ayda 30 tarif ekle",
                                    "Haftalık yemek planı",
                                    "Ne Yesem? önerisi",
                                ],
                                entitlement: "feslihan_plus",
                                highlighted: false
                            )

                            planCard(
                                name: "Feslihan Pro",
                                price: "₺100/ay",
                                features: [
                                    "Sınırsız tarif ekle",
                                    "Haftalık yemek planı",
                                    "Ne Yesem? önerisi",
                                    "Öncelikli destek",
                                ],
                                entitlement: "feslihan_pro",
                                highlighted: true
                            )
                        }
                        .padding(.horizontal, 20)

                        // Error
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red)
                        }

                        // Purchase button
                        if let pkg = selectedPackage {
                            Button(action: { purchase(pkg) }) {
                                Group {
                                    if isPurchasing {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Abone Ol")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(.white)
                                .background(DS.ember)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isPurchasing)
                            .padding(.horizontal, 20)
                        }

                        // Restore
                        Button("Satın alımı geri yükle") {
                            Task { await restore() }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.smoke)

                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.ink)
                    }
                }
            }
            .task {
                await loadOfferings()
            }
        }
    }

    // MARK: - Plan Card

    private func planCard(name: String, price: String, features: [String], entitlement: String, highlighted: Bool) -> some View {
        let isSelected = selectedPackage?.offeringIdentifier == entitlement
            || (selectedPackage == nil && highlighted)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 18, weight: .bold))
                    Text(price)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(highlighted ? DS.cream.opacity(0.8) : DS.smoke)
                }
                Spacer()
                if highlighted {
                    Text("Popüler")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text(feature)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(16)
        .foregroundStyle(highlighted ? .white : DS.ink)
        .background(highlighted ? DS.ember : DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? DS.ember : .clear, lineWidth: 2)
        )
        .onTapGesture {
            // Find matching package from offerings
            if let pkg = offerings?.offering(identifier: entitlement)?.availablePackages.first {
                selectedPackage = pkg
            }
        }
    }

    // MARK: - Actions

    private func loadOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
            // Auto-select pro
            selectedPackage = offerings?.offering(identifier: "feslihan_pro")?.availablePackages.first
                ?? offerings?.current?.availablePackages.first
        } catch {
            print("[Paywall] Failed to load offerings: \(error)")
        }
    }

    private func purchase(_ package: Package) {
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                let result = try await Purchases.shared.purchase(package: package)
                if !result.userCancelled {
                    await subscription.refreshStatus()
                    dismiss()
                }
            } catch {
                errorMessage = "Satın alma başarısız: \(error.localizedDescription)"
            }
            isPurchasing = false
        }
    }

    private func restore() async {
        do {
            _ = try await Purchases.shared.restorePurchases()
            await subscription.refreshStatus()
        } catch {
            errorMessage = "Geri yükleme başarısız"
        }
    }
}
