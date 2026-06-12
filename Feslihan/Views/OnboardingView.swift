import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    @State private var showAddRecipe = false

    private let steps: [(icon: String, title: String, subtitle: String, description: String)] = [
        (
            "leaf.fill",
            "Feslihan'a Hoş Geldin",
            "Anne, ne yesek?",
            "Tariflerini bir araya getir, kilerini takip et ve her gün ne pişireceğine kolayca karar ver."
        ),
        (
            "book.closed.fill",
            "Tariflerini Ekle",
            "Sosyal medyadaki tarifleri kaydet",
            "Instagram, TikTok veya web'den tarif linkini yapıştır — gerisini biz halledelim."
        ),
        (
            "cabinet.fill",
            "Kilerini Doldur",
            "Evdeki malzemeleri ekle",
            "Kilerindeki malzemeleri ekleyince sana özel tarif önerileri sunabiliriz."
        )
    ]

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentStep < steps.count - 1 {
                        Button("Atla") {
                            hasCompletedOnboarding = true
                        }
                        .font(.label())
                        .foregroundStyle(DS.dust)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(height: 36)

                Spacer()

                // Illustration
                let step = steps[currentStep]
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(DS.emberLight)
                            .frame(width: 120, height: 120)

                        Image(systemName: step.icon)
                            .font(.system(size: 54, weight: .medium))
                            .foregroundStyle(DS.ember)
                    }

                    VStack(spacing: 10) {
                        Text(step.title)
                            .font(.displayLarge())
                            .foregroundStyle(DS.ink)
                            .multilineTextAlignment(.center)

                        Text(step.subtitle)
                            .font(.handwritten())
                            .foregroundStyle(DS.smoke)

                        Text(step.description)
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? DS.ember : DS.stone)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 32)

                // Button
                Button {
                    if currentStep == 1 {
                        showAddRecipe = true
                    } else if currentStep < steps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep += 1
                        }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(buttonTitle)
                        .font(.buttonFont())
                        .foregroundStyle(DS.flour)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(DS.ember)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: DS.shadowButton, radius: 8, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Secondary action on recipe step
                if currentStep == 1 {
                    Button("Sonra eklerim") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep += 1
                        }
                    }
                    .font(.label())
                    .foregroundStyle(DS.dust)
                    .padding(.bottom, 24)
                } else if currentStep == 2 {
                    Button("Sonra doldururum") {
                        hasCompletedOnboarding = true
                    }
                    .font(.label())
                    .foregroundStyle(DS.dust)
                    .padding(.bottom, 24)
                } else {
                    Spacer().frame(height: 44)
                }
            }
        }
        .sheet(isPresented: $showAddRecipe, onDismiss: {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep += 1
            }
        }) {
            AddRecipeView()
        }
    }

    private var buttonTitle: String {
        switch currentStep {
        case 0: return "Başlayalım"
        case 1: return "İlk Tarifimi Ekle"
        case 2: return "Kilerimi Doldurmaya Başla"
        default: return "Devam"
        }
    }
}
