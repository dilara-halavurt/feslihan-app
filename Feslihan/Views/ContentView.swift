import SwiftUI

struct ContentView: View {
    var onBack: (() -> Void)?

    var body: some View {
        RecipeListView(onBack: onBack)
    }
}
