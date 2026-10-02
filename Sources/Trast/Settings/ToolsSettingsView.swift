import SwiftUI
import TrastCore

struct ToolsSettingsView: View {
    @AppStorage(AppSettings.aiProviderKey) private var aiProvider = "openai"
    @AppStorage(AppSettings.aiAPIKeyKey) private var aiAPIKey = ""

    var body: some View {
        Form {
            Section {
                HotkeyRecorderView("Open Text Transformer:", name: HotkeyManager.openTextTransformer)
            } header: {
                Text("Text Transformer")
            } footer: {
                Text("Opens the Launcher on the Text Transformer. Select text in any app first — it reads the selection and replaces it in place when you pick a transformation. Your clipboard is untouched.")
            }

            Section {
                HotkeyRecorderView("Open AI Chat:", name: HotkeyManager.openAIChat)
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
                Text("AI Chat — coming soon")
            } footer: {
                Text("The chat interface is under development. Your provider and API key are stored locally on this Mac and ready for when it ships; nothing is sent anywhere yet.")
            }
        }
        .formStyle(.grouped)
    }
}
