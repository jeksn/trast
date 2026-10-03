import SwiftUI
import TrastCore

struct TextTransformerSettingsView: View {
    @State private var order: [String] = AppSettings.transformOrder
    @State private var disabled: Set<String> = Set(AppSettings.disabledTransforms)

    var body: some View {
        Form {
            Section {
                HotkeyRecorderView("Open Text Transformer:", name: HotkeyManager.openTextTransformer)
            } header: {
                Text("Hotkey")
            } footer: {
                Text("Opens the Launcher on the Text Transformer. Select text in any app first — it reads the selection and replaces it in place when you pick a transformation. Your clipboard is untouched.")
            }

            Section {
                ForEach(Array(order.enumerated()), id: \.element) { index, raw in
                    transformRow(raw: raw, index: index)
                }
            } header: {
                Text("Transformations")
            } footer: {
                Text("Enabled transformations appear in the tool in this order. Disable the ones you never use to keep the list short.")
            }
        }
        .formStyle(.grouped)
    }

    private func transformRow(raw: String, index: Int) -> some View {
        let name = TextTransform(rawValue: raw)?.name ?? raw
        return HStack {
            Toggle(name, isOn: enabledBinding(for: raw))
            Spacer()
            HStack(spacing: 0) {
                Button {
                    move(index, -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 20, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .help("Move up")

                Button {
                    move(index, 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 20, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(index == order.count - 1)
                .help("Move down")
            }
            .foregroundStyle(.secondary)
        }
    }

    private func enabledBinding(for raw: String) -> Binding<Bool> {
        Binding(
            get: { !disabled.contains(raw) },
            set: { isEnabled in
                if isEnabled {
                    disabled.remove(raw)
                } else {
                    disabled.insert(raw)
                }
                AppSettings.saveDisabledTransforms(Array(disabled))
            }
        )
    }

    private func move(_ index: Int, _ delta: Int) {
        let target = index + delta
        guard target >= 0, target < order.count else { return }
        order.swapAt(index, target)
        AppSettings.saveTransformOrder(order)
    }
}
