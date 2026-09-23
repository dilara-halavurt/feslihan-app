import SwiftUI
import ClerkKit

// MARK: - Onboarding

/// A simple two-step onboarding that leads a new user to first add a recipe,
/// then fill their pantry. Shown once after the first sign-in.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @State private var showAddRecipe = false
    @State private var showPantry = false

    private let steps = [
        OnboardingStep(
            icon: "book.closed.fill",
            title: "Önce tariflerini ekle",
            subtitle: "Sevdiğin tarifleri bir bağlantıdan saniyeler içinde defterine ekle. Buradan başlayalım.",
            primaryLabel: "Tarif Ekle"
        ),
        OnboardingStep(
            icon: "refrigerator.fill",
            title: "Sonra kilerini doldur",
            subtitle: "Evdeki malzemeleri ekle ki Feslihan sana en uygun tarifleri önerebilsin.",
            primaryLabel: "Malzeme Ekle"
        )
    ]

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    Button("Atla") { onComplete() }
                        .font(.label())
                        .foregroundStyle(DS.dust)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                let current = steps[step]

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(DS.emberLight)
                            .frame(width: 104, height: 104)

                        Image(systemName: current.icon)
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(DS.ember)
                    }

                    VStack(spacing: 10) {
                        Text(current.title)
                            .font(.displayTitle())
                            .foregroundStyle(DS.ink)
                            .multilineTextAlignment(.center)

                        Text(current.subtitle)
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                }
                .id(step)
                .transition(.opacity)

                Spacer()

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == step ? DS.ember : DS.stone)
                            .frame(width: index == step ? 22 : 8, height: 8)
                    }
                }
                .padding(.bottom, 24)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        if step == 0 {
                            showAddRecipe = true
                        } else {
                            showPantry = true
                        }
                    } label: {
                        Text(current.primaryLabel)
                            .font(.buttonFont())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(DS.flour)
                            .background(DS.ember)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: DS.shadowButton, radius: 8, y: 4)
                    }

                    Button {
                        advance()
                    } label: {
                        Text(step == 0 ? "Daha Sonra" : "Başla")
                            .font(.buttonFont())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(DS.ember)
                            .background(DS.emberLight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showAddRecipe, onDismiss: advance) {
            AddRecipeView()
        }
        .fullScreenCover(isPresented: $showPantry, onDismiss: advance) {
            PantryBubbleSheet(
                existingNames: [],
                onSave: { names in
                    guard let userId = Clerk.shared.user?.id else { return }
                    Task { _ = await APIService.addToPantry(userId: userId, ingredientNames: names) }
                }
            )
        }
    }

    private func advance() {
        if step == 0 {
            withAnimation(.easeInOut(duration: 0.25)) { step = 1 }
        } else {
            onComplete()
        }
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let subtitle: String
    let primaryLabel: String
}
