import WindowPaneCore
import SwiftUI
import KeyboardShortcuts

struct PickerView: View {
    @ObservedObject var viewModel: PickerViewModel
    let onSelect: (PickerItem) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Type a command or app name", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($isFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if viewModel.filtered.isEmpty {
                Text("No matching items")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.sections) { section in
                                HStack {
                                    Text(section.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 8)
                                        .padding(.bottom, 2)
                                    Spacer()
                                }
                                ForEach(section.items) { item in
                                    PickerRowView(item: item, isSelected: item.id == viewModel.filtered[safe: viewModel.selectedIndex]?.id)
                                        .id(item.id)
                                        .onTapGesture { onSelect(item) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: viewModel.selectedIndex) { index in
                        if let item = viewModel.filtered[safe: index] {
                            proxy.scrollTo(item.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 560, height: 380)
        .background(.regularMaterial)
        .ignoresSafeArea(edges: .top)
        .onAppear { isFocused = true }
        .onChange(of: viewModel.focusToken) { _ in isFocused = true }
        .onExitCommand { PickerController.shared.close() }
    }
}

struct PickerRowView: View {
    let item: PickerItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(item.title.isEmpty ? "Untitled" : item.title)
                .lineLimit(1)
            Spacer()
            if let shortcut = KeyboardShortcuts.getShortcut(for: item.hotkeyName) {
                Text(shortcut.description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .padding(.horizontal, 6)
    }
}
