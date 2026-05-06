import SwiftUI

struct SettingsView: View {
    @AppStorage("openai_api_key") private var openAIKey = ""
    @AppStorage("anthropic_api_key") private var anthropicKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("API Anahtarları") {
                    SecureField("OpenAI API Key", text: $openAIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Anthropic API Key", text: $anthropicKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Text("API anahtarlarını ilgili platformların web sitelerinden alabilirsiniz.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ayarlar")
        }
    }
}
