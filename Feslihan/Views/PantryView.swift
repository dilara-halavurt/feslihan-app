import SwiftUI
import ClerkKit

struct PantryView: View {
    var onBack: (() -> Void)?

    @State private var items: [PantryItemDTO] = []
    @State private var isLoading = true
    @State private var showBubbleGame = false
    @State private var bubbleSelection: Set<String> = []

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(DS.ember)
                    Spacer()
                } else if items.isEmpty {
                    emptyState
                } else {
                    pantryList
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let onBack {
                BackButton(action: onBack)
                    .padding(.leading, 16)
                    .padding(.top, 8)
            }
        }
        .overlay(alignment: .bottom) {
            Button {
                bubbleSelection = []
                showBubbleGame = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Malzeme Ekle")
                        .font(.buttonFont())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(DS.ember)
                .foregroundStyle(DS.cream)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: DS.ember.opacity(0.25), radius: 8, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .fullScreenCover(isPresented: $showBubbleGame) {
            ZStack {
                BubbleGameView(selected: $bubbleSelection) {
                    Task {
                        await saveSelection()
                        showBubbleGame = false
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                BackButton(action: { showBubbleGame = false })
                    .padding(.leading, 16)
                    .padding(.top, 8)
            }
        }
        .task {
            await load()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Kilerim")
                .font(.displayTitle())
                .foregroundStyle(DS.ink)

            Text("Evindeki malzemeleri takip et")
                .font(.bodyText())
                .foregroundStyle(DS.smoke)
        }
        .padding(.top, 60)
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(DS.dust)
            Text("Kilerin boş")
                .font(.sectionHeader())
                .foregroundStyle(DS.ink)
            Text("Baloncuk oyununu oynayarak\nmalzeme ekleyebilirsin")
                .font(.bodyText())
                .foregroundStyle(DS.smoke)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var pantryList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.pine)
                            .frame(width: 32, height: 32)
                            .background(DS.pine.opacity(0.12))
                            .clipShape(Circle())

                        Text(item.ingredient_name)
                            .font(.label())
                            .foregroundStyle(DS.ink)

                        Spacer()

                        Button {
                            Task { await remove(item) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DS.smoke)
                                .frame(width: 28, height: 28)
                                .background(DS.sand)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    private func load() async {
        guard let userId = Clerk.shared.user?.id else {
            isLoading = false
            return
        }
        items = await APIService.fetchPantry(userId: userId)
        isLoading = false
    }

    private func saveSelection() async {
        guard let userId = Clerk.shared.user?.id else { return }
        let existing = Set(items.map { $0.ingredient_name })
        let toAdd = bubbleSelection.subtracting(existing)
        for name in toAdd {
            await APIService.addPantryItem(userId: userId, ingredientName: name)
        }
        items = await APIService.fetchPantry(userId: userId)
    }

    private func remove(_ item: PantryItemDTO) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let ok = await APIService.deletePantryItem(userId: userId, ingredientName: item.ingredient_name)
        if ok {
            items.removeAll { $0.id == item.id }
        }
    }
}
