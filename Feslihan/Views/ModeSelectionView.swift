import SwiftUI
import ClerkKit
import ClerkKitUI

enum AppMode: String, CaseIterable {
    case mealPrep
    case whatToEat
    case browse
}

struct ModeSelectionView: View {
    @State private var selectedMode: AppMode?
    @State private var cardsVisible = false
    @State private var showAddRecipe = false
    @State private var showPaywall = false
    @State private var showMealPrepWizard = false
    @EnvironmentObject var subscription: SubscriptionService

    private func goBack() {
        withAnimation(.spring(response: 0.2)) {
            selectedMode = nil
        }
    }

    var body: some View {
        if let mode = selectedMode {
            Group {
                switch mode {
                case .browse:
                    ContentView(onBack: goBack)
                case .mealPrep:
                    SavedMealPlansView(
                        onBack: goBack,
                        onCreateNew: {
                            withAnimation(.spring(response: 0.2)) {
                                selectedMode = nil
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.2)) {
                                    showMealPrepWizard = true
                                }
                            }
                        }
                    )
                case .whatToEat:
                    WhatToEatView(onBack: goBack)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            ZStack {
                DS.cream.ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        UserButton()
                            .frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    VStack(spacing: 8) {

                        Text("Bir mod seç ve başla")
                            .font(.bodyText())
                            .foregroundStyle(DS.smoke)
                    }

                    VStack(spacing: 12) {
                        ModeCard(
                            icon: "calendar",
                            title: "Meal Prep",
                            subtitle: "Haftalık yemek planı oluştur"
                        )
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 20)
                        .onTapGesture {
                            if subscription.currentPlan.canMealPrep {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedMode = .mealPrep
                                }
                            } else {
                                showPaywall = true
                            }
                        }

                        ModeCard(
                            icon: "sparkles",
                            title: "Ne Yesem?",
                            subtitle: "Malzemelerine göre tarif bul"
                        )
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 20)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2)) {
                                selectedMode = .whatToEat
                            }
                        }

                        ModeCard(
                            icon: "book",
                            title: "Tariflerim",
                            subtitle: "Kaydettiğin tariflere göz at"
                        )
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 20)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2)) {
                                selectedMode = .browse
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .overlay(alignment: .bottom) {
                Button(action: { showAddRecipe = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.cream)
                        .frame(width: 56, height: 56)
                        .background(DS.ember)
                        .clipShape(Circle())
                        .shadow(color: DS.ember.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $showAddRecipe) {
                AddRecipeView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showMealPrepWizard) {
                MealPrepView(onBack: { showMealPrepWizard = false })
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.2).delay(0.05)) {
                    cardsVisible = true
                }
            }
        }
    }
}

private struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DS.ember)
                .frame(width: 48, height: 48)
                .background(DS.emberLight)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.sectionHeader())
                    .foregroundStyle(DS.ink)

                Text(subtitle)
                    .font(.label())
                    .foregroundStyle(DS.smoke)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.dust)
        }
        .padding(16)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
