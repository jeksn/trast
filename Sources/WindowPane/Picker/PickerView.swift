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
                                    PickerRowView(item: item, isSelected: item.id == viewModel.filtered[safe: viewModel.selectedIndex]?.id, query: viewModel.query)
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
    let query: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            if let nsImage = item.iconImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: item.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            highlightedTitle
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
                .fill(rowBackground)
        )
        .padding(.horizontal, 6)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if isHovered { return Color.accentColor.opacity(0.10) }
        return Color.clear
    }

    private var highlightedTitle: Text {
        let title = item.title.isEmpty ? "Untitled" : item.title
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty,
              let indices = FuzzyMatch.matchedIndices(query: trimmedQuery, target: title),
              !indices.isEmpty else {
            return Text(title)
        }

        let matchedSet = Set(indices)
        var result = AttributedString()
        for (i, char) in title.enumerated() {
            var attributed = AttributedString(String(char))
            if matchedSet.contains(i) {
                attributed.font = .body.weight(.semibold)
            }
            result += attributed
        }
        return Text(result)
    }
}
