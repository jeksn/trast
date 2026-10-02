import TrastCore
import SwiftUI
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
                                        LauncherRowView(
                                            item: item,
                                            isSelected: item.id == selectedID,
                                            query: viewModel.query,
                                            hotkeyDisplay: viewModel.hotkeyDisplay(for: item),
                                            canFavorite: viewModel.isFavoritable(item),
                                            isFavorite: viewModel.isFavorite(item),
                                            onToggleFavorite: { viewModel.toggleFavorite(item.id) }
                                        )
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
                } else if viewModel.selectedCategory == .all && !viewModel.showsRecentActivity {
                    Text("Press ↓ for recent activity · ⇥ for tools · ⌘K for options")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if showsOptionsFooter {
                Divider()
                HStack {
                    Spacer()
                    Text("⌘K Options")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 16)
                        .padding(.vertical, 6)
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
            .help("Show tools (Tab)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var actionsList: some View {
        let tools = LauncherViewModel.Category.toolCases
        let browse = LauncherViewModel.Category.browseCases
        return VStack(alignment: .leading, spacing: 10) {
            if !tools.isEmpty {
                actionsHeader("Tools")
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(Array(tools.enumerated()), id: \.element) { index, category in
                        LauncherToolTile(
                            category: category,
                            number: index + 1,
                            isSelected: index == viewModel.gridIndex,
                            isPlaceholder: category.isPlaceholder
                        )
                        .onTapGesture {
                            if !category.isPlaceholder {
                                viewModel.selectCategory(category)
                            }
                        }
                    }
                }
            }

            actionsHeader("Browse")
            VStack(spacing: 10) {
                ForEach(Array(browse.enumerated()), id: \.element) { index, category in
                    LauncherCategoryTile(
                        category: category,
                        number: tools.count + index + 1,
                        isSelected: tools.count + index == viewModel.gridIndex
                    )
                    .onTapGesture { viewModel.selectCategory(category) }
                }
            }
        }
        .padding(14)
    }

    private func actionsHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
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

    private var selectedID: String? {
        viewModel.filtered[safe: viewModel.selectedIndex]?.id
    }

    /// The ⌘K hint shows whenever a result row can have options — search
    /// results, category lists, and the recents view, but not the actions
    /// view or the scratchpad editor.
    private var showsOptionsFooter: Bool {
        !viewModel.showsActions
            && viewModel.selectedCategory != .scratchpad
            && !viewModel.filtered.isEmpty
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

struct LauncherToolTile: View {
    let category: LauncherViewModel.Category
    let number: Int
    let isSelected: Bool
    var isPlaceholder = false

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Text(category.label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 2) {
                Image(systemName: "command")
                    .font(.system(size: 7, weight: .bold))
                Text(isPlaceholder ? "soon" : "\(number)")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .opacity(isPlaceholder ? 0.45 : 1)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(tileBackground)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { isHovered = $0 }
        .help(isPlaceholder ? "Coming soon" : category.label)
    }

    private var tileBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if isHovered && !isPlaceholder { return Color.accentColor.opacity(0.10) }
        return Color.secondary.opacity(0.08)
    }
}

struct LauncherCategoryTile: View {
    let category: LauncherViewModel.Category
    let number: Int
    let isSelected: Bool

    @State private var isHovered = false

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
                .fill(rowBackground)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if isHovered { return Color.accentColor.opacity(0.10) }
        return Color.secondary.opacity(0.08)
    }
}

struct LauncherRowView: View {
    let item: LauncherItem
    let isSelected: Bool
    let query: String
    let hotkeyDisplay: String?
    var canFavorite = false
    var isFavorite = false
    var onToggleFavorite: (() -> Void)? = nil

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
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
            if let hotkeyDisplay {
                Text(hotkeyDisplay)
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
        .contextMenu {
            if canFavorite, let onToggleFavorite {
                Button(isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                    onToggleFavorite()
                }
            }
        }
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

        // Build matched/unmatched runs instead of one AttributedString per
        // character — the per-character version allocated a string per glyph
        // per row on every keystroke.
        let matchedSet = Set(indices)
        var result = AttributedString()
        var run = ""
        var runIsMatched = matchedSet.contains(0)

        func flushRun() {
            guard !run.isEmpty else { return }
            var attributed = AttributedString(run)
            if runIsMatched {
                attributed.font = .body.weight(.bold)
                attributed.underlineStyle = Text.LineStyle(pattern: .solid)
            }
            result += attributed
            run = ""
        }

        for (offset, char) in title.enumerated() {
            let isMatched = matchedSet.contains(offset)
            if isMatched != runIsMatched {
                flushRun()
                runIsMatched = isMatched
            }
            run.append(char)
        }
        flushRun()
        return Text(result)
    }
}
