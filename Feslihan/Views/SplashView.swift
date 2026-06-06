import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.75
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var finished = false

    var body: some View {
        if finished {
            ModeSelectionView()
                .transition(.opacity)
        } else {
            ZStack {
                DS.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 22) {
                        // Leaf icon in circle
                        ZStack {
                            Circle()
                                .fill(DS.emberLight)
                                .frame(width: 96, height: 96)

                            Image(systemName: "leaf.fill")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundStyle(DS.ember)
                        }
                        .scaleEffect(iconScale)

                        Text("Feslihan")
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)
                            .opacity(titleOpacity)

                        Text("Anne, ne yesek?")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(DS.smoke)
                            .opacity(subtitleOpacity)
                    }

                    Spacer()

                    // Loading spinner
                    ProgressView()
                        .tint(DS.ember)
                        .padding(.bottom, 60)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    iconScale = 1.0
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
                    titleOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
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
