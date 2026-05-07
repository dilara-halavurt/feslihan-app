import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var finished = false

    var body: some View {
        if finished {
            ModeSelectionView()
                .transition(.opacity)
        } else {
            ZStack {
                DS.ember.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(DS.cream)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)

                    Text("Feslihan")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.cream)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)

                    Text("Anne ne yesek?")
                        .font(.bodyText())
                        .foregroundStyle(DS.cream.opacity(0.7))
                        .opacity(subtitleOpacity)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.2).delay(0.4)) {
                    titleOffset = 0
                    titleOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.2).delay(0.6)) {
                    subtitleOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        finished = true
                    }
                }
            }
        }
    }
}
