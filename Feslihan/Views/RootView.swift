import SwiftUI
import ClerkKit
import ClerkKitUI

struct RootView: View {
    @State private var authIsPresented = false
    @Bindable private var clerk = Clerk.shared

    var body: some View {
        if let user = clerk.user {
            SplashView()
                .task {
                    await syncUserToBackend(user)
                    SubscriptionService.shared.setUser(user.id)
                    await SubscriptionService.shared.refreshStatus()
                }
        } else {
            ZStack {
                DS.cream.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 72, weight: .medium))
                            .foregroundStyle(DS.ember)

                        Text("Feslihan")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.ink)

                        Text("Anne ne yesek?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DS.smoke)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            authIsPresented = true
                        } label: {
                            Text("Giriş Yap")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(.white)
                                .background(DS.ember)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            authIsPresented = true
                        } label: {
                            Text("Hesap Oluştur")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(DS.ink)
                                .background(DS.sand)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(DS.stone, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $authIsPresented) {
                AuthView()
            }
        }
    }

    private func syncUserToBackend(_ user: ClerkKit.User) async {
        guard let url = URL(string: "\(APIService.baseURL)/users/sync") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any?] = [
            "clerk_id": user.id,
            "email": user.primaryEmailAddress?.emailAddress,
            "name": [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " "),
            "avatar_url": user.imageUrl
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        _ = try? await URLSession.shared.data(for: request)
    }
}
