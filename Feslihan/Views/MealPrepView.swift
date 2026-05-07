import SwiftUI
import ClerkKit

// MARK: - Wizard Data Types

enum PeopleCount: String, CaseIterable {
    case one = "1 Kişi"
    case two = "2 Kişi"
    case threeToFour = "3-4 Kişi"
    case fivePlus = "5+ Kişi"

    var icon: String {
        switch self {
        case .one: return "person.fill"
        case .two: return "person.2.fill"
        case .threeToFour: return "person.3.fill"
        case .fivePlus: return "person.3.sequence.fill"
        }
    }

    var apiValue: String {
        switch self {
        case .one: return "1"
        case .two: return "2"
        case .threeToFour: return "3-4"
        case .fivePlus: return "5+"
        }
    }
}

enum MealsPerDay: String, CaseIterable {
    case two = "2 Öğün"
    case three = "3 Öğün"
    case fourPlus = "4+ Öğün"

    var icon: String {
        switch self {
        case .two: return "sun.max.fill"
        case .three: return "clock.fill"
        case .fourPlus: return "clock.badge.checkmark.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .two: return "Öğle + Akşam"
        case .three: return "Kahvaltı + Öğle + Akşam"
        case .fourPlus: return "Kahvaltı + Öğle + Akşam + Ara"
        }
    }

    var apiValue: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .fourPlus: return "4+"
        }
    }
}

enum EatingStyle: String, CaseIterable {
    case healthy = "Sağlıklı"
    case calorieDeficit = "Kalori Açığı"
    case normal = "Normal"
    case traditional = "Geleneksel"
    case quick = "Pratik"
    case highProtein = "Protein Ağırlıklı"
    case vegetarian = "Vejetaryen"
    case vegan = "Vegan"

    var icon: String {
        switch self {
        case .healthy: return "heart.fill"
        case .calorieDeficit: return "flame.fill"
        case .normal: return "fork.knife"
        case .traditional: return "house.fill"
        case .quick: return "bolt.fill"
        case .highProtein: return "dumbbell.fill"
        case .vegetarian: return "leaf.fill"
        case .vegan: return "carrot.fill"
        }
    }
}

enum MealPrepPeriod: String, CaseIterable {
    case weekly = "Haftalık"
    case biweekly = "2 Haftalık"
    case monthly = "Aylık"

    var icon: String {
        switch self {
        case .weekly: return "calendar"
        case .biweekly: return "calendar.badge.clock"
        case .monthly: return "calendar.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .weekly: return "7 günlük plan"
        case .biweekly: return "14 günlük plan"
        case .monthly: return "30 günlük plan"
        }
    }

    var apiValue: String {
        switch self {
        case .weekly: return "7 gün"
        case .biweekly: return "14 gün"
        case .monthly: return "30 gün"
        }
    }
}

enum PrepStyle: String, CaseIterable {
    case freezeAhead = "Hazırla & Dondur"
    case freshDaily = "Her Gün Taze"
    case mix = "Karışık"

    var icon: String {
        switch self {
        case .freezeAhead: return "snowflake"
        case .freshDaily: return "leaf.fill"
        case .mix: return "arrow.triangle.2.circlepath"
        }
    }

    var subtitle: String {
        switch self {
        case .freezeAhead: return "Hafta başı hazırla, dondur, ısıtarak ye"
        case .freshDaily: return "Her gün taze taze pişir"
        case .mix: return "Bazılarını dondur, bazılarını taze yap"
        }
    }
}

enum BudgetLevel: String, CaseIterable {
    case economic = "Ekonomik"
    case moderate = "Orta"
    case noLimit = "Farketmez"

    var icon: String {
        switch self {
        case .economic: return "turkishlirasign"
        case .moderate: return "turkishlirasign.arrow.trianglehead.counterclockwise.rotate.90"
        case .noLimit: return "sparkles"
        }
    }
}

// MARK: - Main Wizard Flow

struct MealPrepView: View {
    var onBack: (() -> Void)?

    @State private var step: MealPrepStep = .people
    @State private var peopleCount: PeopleCount = .two
    @State private var mealsPerDay: MealsPerDay = .three
    @State private var eatingStyles: Set<EatingStyle> = []
    @State private var period: MealPrepPeriod = .weekly
    @State private var hasKids = false
    @State private var kidsCount = 1
    @State private var prepStyle: PrepStyle = .mix
    @State private var budget: BudgetLevel = .moderate

    enum MealPrepStep: CaseIterable {
        case people, meals, style, period, kids, prepStyle, budget, result
    }

    private var currentStepIndex: Int {
        MealPrepStep.allCases.firstIndex(of: step) ?? 0
    }

    private var totalSteps: Int { 7 } // excluding result

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            switch step {
            case .people:
                PeopleStepView(selected: $peopleCount) {
                    advance(to: .meals)
                }
                .transition(.move(edge: .trailing))

            case .meals:
                MealsStepView(selected: $mealsPerDay) {
                    advance(to: .style)
                }
                .transition(.move(edge: .trailing))

            case .style:
                StyleStepView(selected: $eatingStyles) {
                    advance(to: .period)
                }
                .transition(.move(edge: .trailing))

            case .period:
                PeriodStepView(selected: $period) {
                    advance(to: .kids)
                }
                .transition(.move(edge: .trailing))

            case .kids:
                KidsStepView(hasKids: $hasKids, kidsCount: $kidsCount) {
                    advance(to: .prepStyle)
                }
                .transition(.move(edge: .trailing))

            case .prepStyle:
                PrepStyleStepView(selected: $prepStyle) {
                    advance(to: .budget)
                }
                .transition(.move(edge: .trailing))

            case .budget:
                BudgetStepView(selected: $budget) {
                    advance(to: .result)
                }
                .transition(.move(edge: .trailing))

            case .result:
                MealPlanResultView(
                    peopleCount: peopleCount,
                    mealsPerDay: mealsPerDay,
                    eatingStyles: eatingStyles,
                    period: period,
                    hasKids: hasKids,
                    prepStyle: prepStyle,
                    kidsCount: kidsCount,
                    budget: budget
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.3), value: step)
        .overlay(alignment: .topLeading) {
            BackButton(action: goBack)
                .padding(.leading, 16)
                .padding(.top, 8)
        }
        .overlay(alignment: .top) {
            if step != .result {
                ProgressBar(current: currentStepIndex, total: totalSteps)
                    .padding(.horizontal, 60)
                    .padding(.top, 16)
            }
        }
    }

    private func advance(to next: MealPrepStep) {
        withAnimation(.spring(response: 0.3)) {
            step = next
        }
    }

    private func goBack() {
        let steps = MealPrepStep.allCases
        if let idx = steps.firstIndex(of: step), idx > 0 {
            withAnimation(.spring(response: 0.3)) {
                step = steps[idx - 1]
            }
        } else {
            onBack?()
        }
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.sand)
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.ember)
                    .frame(width: geo.size.width * CGFloat(current + 1) / CGFloat(total), height: 4)
                    .animation(.easeOut(duration: 0.3), value: current)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Step 1: People Count

private struct PeopleStepView: View {
    @Binding var selected: PeopleCount
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Kaç kişilik yemek yapıyorsun?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(Array(PeopleCount.allCases.enumerated()), id: \.element) { index, count in
                    Button {
                        selected = count
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: count.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 32)

                            Text(count.rawValue)
                                .font(.sectionHeader())

                            Spacer()

                            if selected == count {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(16)
                        .foregroundStyle(selected == count ? DS.cream : DS.ink)
                        .background(selected == count ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Devam Et")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 2: Meals Per Day

private struct MealsStepView: View {
    @Binding var selected: MealsPerDay
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Günde kaç öğün?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
            }

            VStack(spacing: 8) {
                ForEach(Array(MealsPerDay.allCases.enumerated()), id: \.element) { index, meal in
                    Button {
                        selected = meal
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: meal.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.rawValue)
                                    .font(.sectionHeader())
                                Text(meal.subtitle)
                                    .font(.captionText())
                                    .opacity(0.7)
                            }

                            Spacer()

                            if selected == meal {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(16)
                        .foregroundStyle(selected == meal ? DS.cream : DS.ink)
                        .background(selected == meal ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Devam Et")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 3: Eating Style (Multi-select)

private struct StyleStepView: View {
    @Binding var selected: Set<EatingStyle>
    var onDone: () -> Void

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Nasıl beslenmeyi seviyorsun?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
                    .multilineTextAlignment(.center)

                Text("Birden fazla seçebilirsin")
                    .font(.captionText())
                    .foregroundStyle(DS.smoke)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(EatingStyle.allCases.enumerated()), id: \.element) { index, style in
                    let isSelected = selected.contains(style)
                    Button {
                        if isSelected {
                            selected.remove(style)
                        } else {
                            selected.insert(style)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: style.icon)
                                .font(.system(size: 22, weight: .medium))

                            Text(style.rawValue)
                                .font(.label())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .foregroundStyle(isSelected ? DS.cream : DS.ink)
                        .background(isSelected ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .scaleEffect(appeared ? 1 : 0.97)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.03),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Devam Et (\(selected.count) seçildi)")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selected.isEmpty ? DS.ember.opacity(0.4) : DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(selected.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 4: Time Period

private struct PeriodStepView: View {
    @Binding var selected: MealPrepPeriod
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Ne kadarlık plan istiyorsun?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(Array(MealPrepPeriod.allCases.enumerated()), id: \.element) { index, p in
                    Button {
                        selected = p
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: p.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.rawValue)
                                    .font(.sectionHeader())
                                Text(p.subtitle)
                                    .font(.captionText())
                                    .opacity(0.7)
                            }

                            Spacer()

                            if selected == p {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(16)
                        .foregroundStyle(selected == p ? DS.cream : DS.ink)
                        .background(selected == p ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Devam Et")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 5: Kids

private struct KidsStepView: View {
    @Binding var hasKids: Bool
    @Binding var kidsCount: Int
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Çocuklar için de\nhazırlayacak mısın?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.2)) { hasKids = false }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 32)

                        Text("Hayır, sadece yetişkinler")
                            .font(.sectionHeader())

                        Spacer()

                        if !hasKids {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .padding(16)
                    .foregroundStyle(!hasKids ? DS.cream : DS.ink)
                    .background(!hasKids ? DS.ember : DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.2).delay(0.0), value: appeared)

                Button {
                    withAnimation(.spring(response: 0.2)) { hasKids = true }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "face.smiling.inverse")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 32)

                        Text("Evet, çocuklar da var")
                            .font(.sectionHeader())

                        Spacer()

                        if hasKids {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .padding(16)
                    .foregroundStyle(hasKids ? DS.cream : DS.ink)
                    .background(hasKids ? DS.ember : DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.2).delay(0.05), value: appeared)

                if hasKids {
                    VStack(spacing: 12) {
                        Text("Kaç çocuk?")
                            .font(.label())
                            .foregroundStyle(DS.smoke)

                        HStack(spacing: 20) {
                            Button {
                                if kidsCount > 1 { kidsCount -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(kidsCount > 1 ? DS.ember : DS.dust)
                            }
                            .disabled(kidsCount <= 1)

                            Text("\(kidsCount)")
                                .font(.displayLarge())
                                .foregroundStyle(DS.ink)
                                .frame(width: 50)

                            Button {
                                if kidsCount < 6 { kidsCount += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(kidsCount < 6 ? DS.ember : DS.dust)
                            }
                            .disabled(kidsCount >= 6)
                        }
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Devam Et")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 6: Prep Style

private struct PrepStyleStepView: View {
    @Binding var selected: PrepStyle
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Nasıl hazırlamak istersin?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(Array(PrepStyle.allCases.enumerated()), id: \.element) { index, style in
                    Button {
                        selected = style
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: style.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.rawValue)
                                    .font(.sectionHeader())
                                Text(style.subtitle)
                                    .font(.captionText())
                                    .opacity(0.7)
                            }

                            Spacer()

                            if selected == style {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(16)
                        .foregroundStyle(selected == style ? DS.cream : DS.ink)
                        .background(selected == style ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Devam Et")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 7: Budget

private struct BudgetStepView: View {
    @Binding var selected: BudgetLevel
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "banknote")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.ember)

                Text("Bütçen nasıl?")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)
            }

            VStack(spacing: 8) {
                ForEach(Array(BudgetLevel.allCases.enumerated()), id: \.element) { index, level in
                    Button {
                        selected = level
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: level.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 32)

                            Text(level.rawValue)
                                .font(.sectionHeader())

                            Spacer()

                            if selected == level {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(16)
                        .foregroundStyle(selected == level ? DS.cream : DS.ink)
                        .background(selected == level ? DS.ember : DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Planı Oluştur")
                    .font(.buttonFont())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.ember)
                    .foregroundStyle(DS.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Result View

struct MealPlanResultView: View {
    let peopleCount: PeopleCount
    let mealsPerDay: MealsPerDay
    let eatingStyles: Set<EatingStyle>
    let period: MealPrepPeriod
    let hasKids: Bool
    let prepStyle: PrepStyle
    let kidsCount: Int
    let budget: BudgetLevel

    @State private var plan: MealPlan?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedDay: String?
    @State private var swappingMeal: MealPlanMeal?
    @State private var userRecipes: [RecipeDTO] = []
    @State private var isSaving = false
    @State private var isSaved = false
    @State private var showShoppingList = false
    @State private var addingToDayId: String?
    @State private var editingMeal: MealPlanMeal?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Yemek Planın")
                    .font(.displayTitle())
                    .foregroundStyle(DS.ink)

                Text("\(period.rawValue) - \(peopleCount.rawValue)")
                    .font(.captionText())
                    .foregroundStyle(DS.smoke)
            }
            .padding(.top, 50)
            .padding(.bottom, 16)

            if isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text("Planın hazırlanıyor...")
                        .font(.bodyText())
                        .foregroundStyle(DS.smoke)
                    Text("Bu biraz sürebilir")
                        .font(.captionText())
                        .foregroundStyle(DS.dust)
                }
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(DS.honey)

                    Text("Bir sorun oluştu")
                        .font(.sectionHeader())
                        .foregroundStyle(DS.ink)

                    Text(error)
                        .font(.captionText())
                        .foregroundStyle(DS.smoke)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button("Tekrar Dene") {
                        Task { await loadPlan() }
                    }
                    .font(.buttonFont())
                    .foregroundStyle(DS.ember)
                    .padding(.top, 8)
                }
                Spacer()
            } else if let plan {
                ScrollView {
                    // Summary card
                    HStack(spacing: 16) {
                        SummaryPill(icon: "fork.knife", value: "\(plan.totalRecipes)", label: "Tarif")
                        SummaryPill(icon: "cart", value: "\(plan.shoppingList.count)", label: "Malzeme")
                        if let cal = plan.avgCaloriesPerDay {
                            SummaryPill(icon: "flame", value: "\(cal)", label: "kcal/gün")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // Days
                    LazyVStack(spacing: 8) {
                        ForEach(plan.days) { day in
                            DayCard(day: day, isExpanded: expandedDay == day.id, onTap: {
                                withAnimation(.spring(response: 0.2)) {
                                    expandedDay = expandedDay == day.id ? nil : day.id
                                }
                            }, onSwapMeal: { meal in
                                swappingMeal = meal
                            }, onAddMeal: {
                                addingToDayId = day.id
                            }, onEditMeal: { meal in
                                editingMeal = meal
                            })
                        }
                    }
                    .padding(.horizontal, 20)

                    // Save button (shows shopping list after)
                    Button(action: savePlan) {
                        HStack(spacing: 8) {
                            Image(systemName: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 16))
                            Text(isSaved ? "Kaydedildi" : "Planı Kaydet")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(isSaved ? DS.pine : DS.ember)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSaved || isSaving)
                    .padding(.horizontal, 20)

                    // Shopping list button
                    Button {
                        showShoppingList = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 16))
                            Text("Alışveriş Listesi")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("\(plan.shoppingList.count) malzeme")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DS.smoke)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DS.dust)
                        }
                        .padding(16)
                        .foregroundStyle(DS.ink)
                        .background(DS.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 40)
                }
            }
        }
        .task {
            await loadPlan()
            // Fetch user recipes for swapping
            if let userId = await ClerkKit.Clerk.shared.user?.id {
                userRecipes = await APIService.fetchUserRecipes(userId: userId)
            }
        }
        .sheet(isPresented: $showShoppingList) {
            if let plan {
                ShoppingListSheet(items: plan.shoppingList)
            }
        }
        .sheet(item: $swappingMeal) { meal in
            RecipeSwapSheet(
                currentMealName: meal.name,
                recipes: userRecipes,
                onSelect: { selected in
                    replaceMeal(meal, with: selected)
                    swappingMeal = nil
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { addingToDayId != nil },
            set: { if !$0 { addingToDayId = nil } }
        )) {
            RecipeSwapSheet(
                currentMealName: "Yeni öğün ekle",
                recipes: userRecipes,
                onSelect: { selected in
                    addMealToDay(selected)
                    addingToDayId = nil
                }
            )
        }
        .sheet(item: $editingMeal) { meal in
            MealEditSheet(meal: meal, userRecipes: userRecipes) { updated in
                replaceMealById(meal, with: updated)
                editingMeal = nil
            }
        }
    }

    private func replaceMeal(_ meal: MealPlanMeal, with recipe: RecipeDTO) {
        guard var plan else { return }
        for dayIndex in plan.days.indices {
            if let mealIndex = plan.days[dayIndex].meals.firstIndex(where: { $0.id == meal.id }) {
                plan.days[dayIndex].meals[mealIndex].name = recipe.title
                plan.days[dayIndex].meals[mealIndex].description = String(recipe.description.prefix(120))
                plan.days[dayIndex].meals[mealIndex].calories = recipe.calories_total_kcal.map { Int($0) }
                plan.days[dayIndex].meals[mealIndex].ingredients = recipe.ingredients_without_measures
                break
            }
        }
        self.plan = plan
    }

    private func replaceMealById(_ oldMeal: MealPlanMeal, with updated: MealPlanMeal) {
        guard var plan else { return }
        for dayIndex in plan.days.indices {
            if let mealIndex = plan.days[dayIndex].meals.firstIndex(where: { $0.id == oldMeal.id }) {
                plan.days[dayIndex].meals[mealIndex] = updated
                break
            }
        }
        self.plan = plan
    }

    private func addMealToDay(_ recipe: RecipeDTO) {
        guard var plan, let dayId = addingToDayId else { return }
        if let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }) {
            let newMeal = MealPlanMeal(
                mealType: "Ek Öğün",
                name: recipe.title,
                description: String(recipe.description.prefix(120)),
                calories: recipe.calories_total_kcal.map { Int($0) },
                ingredients: recipe.ingredients_without_measures
            )
            plan.days[dayIndex].meals.append(newMeal)
            self.plan = plan
        }
    }

    private func savePlan() {
        guard let plan else { return }
        isSaving = true
        Task {
            guard let userId = await Clerk.shared.user?.id,
                  let url = URL(string: "\(APIService.baseURL)/meal-plans") else {
                isSaving = false
                return
            }

            let planData: [String: Any] = [
                "days": plan.days.map { day in
                    [
                        "day_name": day.name,
                        "meals": day.meals.map { meal in
                            [
                                "meal_type": meal.mealType,
                                "name": meal.name,
                                "description": meal.description ?? "",
                                "calories": meal.calories ?? 0,
                                "ingredients": meal.ingredients
                            ] as [String: Any]
                        }
                    ] as [String: Any]
                },
                "shopping_list": plan.shoppingList,
                "avg_calories_per_day": plan.avgCaloriesPerDay ?? 0
            ]

            // Match meal names to recipe IDs
            let allMealNames = Set(plan.days.flatMap { $0.meals.map { $0.name.lowercased() } })
            let matchedIds = userRecipes
                .filter { allMealNames.contains($0.title.lowercased()) }
                .compactMap { $0.id }

            let body: [String: Any] = [
                "user_id": userId,
                "name": "\(period.rawValue) - \(peopleCount.rawValue)",
                "plan": planData,
                "recipe_ids": matchedIds
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            if let (_, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...201).contains(http.statusCode) {
                withAnimation(.spring(response: 0.3)) {
                    isSaved = true
                }
            }
            isSaving = false
        }
    }

    private func loadPlan() async {
        isLoading = true
        errorMessage = nil

        do {
            plan = try await ClaudeService.generateMealPlan(
                peopleCount: peopleCount.apiValue,
                mealsPerDay: mealsPerDay.apiValue,
                eatingStyles: eatingStyles.map(\.rawValue),
                period: period.apiValue,
                hasKids: hasKids,
                kidsCount: hasKids ? kidsCount : 0,
                prepStyle: prepStyle.rawValue,
                budget: budget.rawValue
            )
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Summary Pill

private struct SummaryPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DS.ember)
            Text(value)
                .font(.sectionHeader())
                .foregroundStyle(DS.ink)
            Text(label)
                .font(.captionText())
                .foregroundStyle(DS.smoke)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Day Card

private struct DayCard: View {
    let day: MealPlanDay
    let isExpanded: Bool
    let onTap: () -> Void
    var onSwapMeal: ((MealPlanMeal) -> Void)?
    var onAddMeal: (() -> Void)?
    var onEditMeal: ((MealPlanMeal) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(day.name)
                        .font(.sectionHeader())
                        .foregroundStyle(DS.ink)

                    Spacer()

                    Text("\(day.meals.count) öğün")
                        .font(.captionText())
                        .foregroundStyle(DS.smoke)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.dust)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(16)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(day.meals) { meal in
                        Button {
                            onEditMeal?(meal)
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(meal.mealType)
                                            .font(.captionText())
                                            .foregroundStyle(DS.ember)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(DS.emberLight)
                                            .clipShape(Capsule())

                                        if let cal = meal.calories {
                                            Text("\(cal) kcal")
                                                .font(.captionText())
                                                .foregroundStyle(DS.smoke)
                                        }
                                    }

                                    Text(meal.name)
                                        .font(.bodyText())
                                        .foregroundStyle(DS.ink)

                                    if let desc = meal.description {
                                        Text(desc)
                                            .font(.captionText())
                                            .foregroundStyle(DS.smoke)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.dust)
                            }
                        }
                        .padding(.vertical, 4)

                        if meal.id != day.meals.last?.id {
                            Rectangle()
                                .fill(DS.stone.opacity(0.5))
                                .frame(height: 1)
                        }
                    }

                    // Add meal button
                    Button {
                        onAddMeal?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Öğün Ekle")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(DS.ember)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.emberLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Meal Plan Model

struct MealPlan {
    var days: [MealPlanDay]
    let shoppingList: [String]
    let avgCaloriesPerDay: Int?

    var totalRecipes: Int {
        days.flatMap(\.meals).count
    }
}

struct MealPlanDay: Identifiable {
    let id: String
    let name: String
    var meals: [MealPlanMeal]
}

struct MealPlanMeal: Identifiable {
    let id = UUID()
    var mealType: String
    var name: String
    var description: String?
    var calories: Int?
    var ingredients: [String]
}

// MARK: - Shopping List Sheet

struct ShoppingListSheet: View {
    let items: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(DS.ember)
                            Text("\(items.count) malzeme")
                                .font(.label())
                                .foregroundStyle(DS.smoke)
                        }
                        .padding(.horizontal, 20)

                        IngredientsView(items: items)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Alışveriş Listesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(DS.ember)
                }
            }
        }
    }
}

// MARK: - Recipe Swap Sheet

struct RecipeSwapSheet: View {
    let currentMealName: String
    let recipes: [RecipeDTO]
    let onSelect: (RecipeDTO) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [RecipeDTO] {
        if searchText.isEmpty { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Current meal info
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.ember)
                        Text("Değiştiriliyor: **\(currentMealName)**")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.smoke)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(DS.sand)

                    // Search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DS.dust)
                        TextField("Tarif ara...", text: $searchText)
                            .font(.system(size: 15))
                    }
                    .padding(12)
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Recipe list
                    List(filtered, id: \.url) { recipe in
                        Button {
                            onSelect(recipe)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(DS.ink)

                                HStack(spacing: 12) {
                                    if let min = recipe.cooking_time_minutes {
                                        Label("\(min) dk", systemImage: "clock")
                                    }
                                    if let cal = recipe.calories_total_kcal {
                                        Label("\(Int(cal)) kcal", systemImage: "flame")
                                    }
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(DS.smoke)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(DS.cream)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Tarif Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(DS.ember)
                }
            }
        }
    }
}
