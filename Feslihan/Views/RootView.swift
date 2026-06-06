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

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 20) {
                        // Leaf icon in circle
                        ZStack {
                            Circle()
                                .fill(DS.emberLight)
                                .frame(width: 84, height: 84)

                            Image(systemName: "leaf.fill")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundStyle(DS.ember)
                        }

                        Text("Feslihan")
                            .font(.system(size: 38, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)

                        Text("Annenin yemek defteri, her zaman cebinde.")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(DS.smoke)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 240)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            authIsPresented = true
                        } label: {
                            Text("Giriş Yap")
                                .font(.buttonFont())
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(DS.flour)
                                .background(DS.ember)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: DS.shadowButton, radius: 8, y: 4)
                        }

                        Button {
                            authIsPresented = true
                        } label: {
                            Text("Kayıt Ol")
                                .font(.buttonFont())
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(DS.ember)
                                .background(DS.emberLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Text("Devam ederek Kullanım Koşulları'nı\nkabul etmiş olursunuz.")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
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
