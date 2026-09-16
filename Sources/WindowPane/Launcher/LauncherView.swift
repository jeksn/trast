import WindowPaneCore
import SwiftUI
import KeyboardShortcuts

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let onSelect: (LauncherItem) -> Void
    @AppStorage(AppSettings.launcherOpacityKey) private var opacity: Double = 0.85

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(viewModel.placeholder, text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($isFocused)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack(spacing: 4) {
                ForEach(LauncherViewModel.Category.visibleCases, id: \.self) { category in
                    Button {
                        viewModel.selectCategory(category)
                    } label: {
                        Image(systemName: category.icon)
                            .font(.system(size: 13))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(category == viewModel.selectedCategory ? Color.accentColor.opacity(0.25) : Color.clear)
                            )
                            .foregroundStyle(category == viewModel.selectedCategory ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(category.label)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if !viewModel.filtered.isEmpty {
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.sections) { section in
                                if shouldShowSectionHeader {
                                    HStack {
                                        Text(section.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)
                                            .padding(.bottom, 2)
                                        Spacer()
                                    }
                                }
                                ForEach(section.items) { item in
                                    LauncherRowView(item: item, isSelected: item.id == viewModel.filtered[safe: viewModel.selectedIndex]?.id, query: viewModel.query)
                                        .id(item.id)
                                        .onTapGesture { onSelect(item) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: viewModel.selectedIndex) { index in
                        if let item = viewModel.filtered[safe: index] {
                            proxy.scrollTo(item.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 640)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .opacity(opacity)
        )
        .ignoresSafeArea(edges: .all)
        .onAppear { isFocused = true }
        .onChange(of: viewModel.focusToken) { _ in isFocused = true }
        .onExitCommand { LauncherController.shared.close() }
    }

    private var shouldShowSectionHeader: Bool {
        viewModel.selectedCategory == .all && viewModel.sections.count > 1
    }
}

struct LauncherRowView: View {
    let item: LauncherItem
    let isSelected: Bool
    let query: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            if let nsImage = item.iconImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: item.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            highlightedTitle
                .lineLimit(1)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let name = item.hotkeyName,
               let shortcut = KeyboardShortcuts.getShortcut(for: name) {
                Text(shortcut.description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
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
