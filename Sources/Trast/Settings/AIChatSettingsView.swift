import SwiftUI
import TrastCore

struct AIChatSettingsView: View {
    @AppStorage(AppSettings.aiProviderKey) private var aiProvider = "openai"
    @AppStorage(AppSettings.aiAPIKeyKey) private var aiAPIKey = ""

    var body: some View {
        Form {
            Section {
                HotkeyRecorderView("Open AI Chat:", name: HotkeyManager.openAIChat)
            } header: {
                Text("Hotkey")
            } footer: {
                Text("Opens the Launcher on the AI Chat tool.")
            }

            Section {
                Picker("Provider", selection: $aiProvider) {
                    Text("OpenAI").tag("openai")
                    Text("Anthropic").tag("anthropic")
                    Text("Google").tag("google")
                    Text("Mistral").tag("mistral")
                    Text("OpenRouter").tag("openrouter")
                }
                SecureField("API Key", text: $aiAPIKey)
                    .privacySensitive()
            } header: {
                Text("API Access — coming soon")
            } footer: {
                Text("The chat interface is under development. Your provider and API key are stored locally on this Mac and ready for when it ships; nothing is sent anywhere yet.")
            }
        }
        .formStyle(.grouped)
    }
}
