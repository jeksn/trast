import TrastCore
import SwiftUI
import KeyboardShortcuts
import AppKit

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let onSelect: (LauncherItem) -> Void
    @AppStorage(AppSettings.launcherOpacityKey) private var opacity: Double = 0.85
    @AppStorage(AppSettings.scratchpadTextKey) private var scratchpadText = ""

    @FocusState private var isFocused: Bool
    @FocusState private var editorFocused: Bool

    @State private var showsCopied = false
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showsActions {
                actionsList
                    .transition(.blurFade)
            } else if viewModel.selectedCategory == .scratchpad {
                scratchpad
                    .transition(.blurFade)
            } else {
                searchField
                    .transition(.blurFade)

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
        }
        .frame(width: 640)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .opacity(opacity)
        )
        .ignoresSafeArea(edges: .all)
        .onAppear {
            DispatchQueue.main.async { focusActiveField() }
        }
        .onChange(of: viewModel.focusToken) { _ in
            DispatchQueue.main.async { focusActiveField() }
        }
        .onChange(of: viewModel.showsActions) { showsActions in
            if !showsActions {
                DispatchQueue.main.async { focusActiveField() }
            }
        }
        .onExitCommand { LauncherController.shared.handleEscape() }
    }

    private func focusActiveField() {
        if viewModel.selectedCategory == .scratchpad && !viewModel.showsActions {
            editorFocused = true
        } else {
            isFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(viewModel.placeholder, text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($isFocused)
            Button {
                viewModel.enterActionsMode()
            } label: {
                Text("⇥")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 22)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .help("Show all categories (Tab)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var actionsList: some View {
        let categories = LauncherViewModel.Category.gridCases
        return VStack(spacing: 10) {
            ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                LauncherCategoryTile(
                    category: category,
                    number: index + 1,
                    isSelected: index == viewModel.gridIndex
                )
                .onTapGesture { viewModel.selectCategory(category) }
            }
        }
        .padding(14)
    }

    private var scratchpad: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $scratchpadText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .frame(height: 300)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                if scratchpadText.isEmpty {
                    Text("Jot something down…")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 21)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 4)

            Divider()

            HStack(spacing: 16) {
                Spacer()

                if confirmClear {
                    Text("Clear scratchpad?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button {
                        scratchpadText = ""
                        confirmClear = false
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .help("Clear the scratchpad")
                    Button {
                        confirmClear = false
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Keep the text")
                } else {
                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(scratchpadText, forType: .string)
                        showsCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showsCopied = false
                        }
                    } label: {
                        Image(systemName: showsCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(scratchpadText.isEmpty)
                    .help(showsCopied ? "Copied" : "Copy to clipboard")
                    .opacity(scratchpadText.isEmpty ? 0.4 : 1)

                    Button {
                        confirmClear = true
                    } label: {
                        Image(systemName: "arrow.circlepath")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(scratchpadText.isEmpty)
                    .help("Clear and start over")
                    .opacity(scratchpadText.isEmpty ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .onChange(of: viewModel.selectedCategory) { category in
            if category != .scratchpad {
                confirmClear = false
            }
        }
        .onChange(of: viewModel.showsActions) { showsActions in
            if showsActions {
                confirmClear = false
            }
        }
    }

    private var shouldShowSectionHeader: Bool {
        viewModel.selectedCategory == .all && viewModel.sections.count > 1
    }
}

private struct BlurFadeModifier: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(1 - progress)
            .blur(radius: progress * 6)
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(
            active: BlurFadeModifier(progress: 1),
            identity: BlurFadeModifier(progress: 0)
        )
    }
}

struct LauncherCategoryTile: View {
    let category: LauncherViewModel.Category
    let number: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Text(category.label)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer()
            HStack(spacing: 2) {
                Image(systemName: "command")
                    .font(.system(size: 8, weight: .bold))
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
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
                Text(shortcut.hyperDescription)
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
                attributed.font = .body.weight(.bold)
                attributed.underlineStyle = Text.LineStyle(pattern: .solid)
            }
            result += attributed
        }
        return Text(result)
    }
}
