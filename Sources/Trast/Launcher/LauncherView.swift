import TrastCore
import SwiftUI
import AppKit

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let onSelect: (LauncherItem) -> Void
    @AppStorage(AppSettings.launcherOpacityKey) private var opacity: Double = 0.85
    @ObservedObject private var notesStore = NotesStore.shared

    @FocusState private var isFocused: Bool
    @FocusState private var editorFocused: Bool

    @State private var showsCopied = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedCategory == .textTransformer {
                transformerTool
                    .transition(.blurFade)
            } else if viewModel.selectedCategory == .aiChat {
                aiChatTool
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
                                            isHovered: viewModel.hoveredID == item.id,
                                            query: viewModel.query,
                                            hotkeyDisplay: viewModel.hotkeyDisplay(for: item),
                                            canFavorite: viewModel.isFavoritable(item),
                                            isFavorite: viewModel.isFavorite(item),
                                            onToggleFavorite: { viewModel.toggleFavorite(item.id) }
                                        )
                                            // No explicit .id() here: rows move
                                            // between sections (favorites ->
                                            // search results) and an explicit
                                            // id makes SwiftUI reuse the same
                                            // view across that move - a reused
                                            // row then silently stops painting
                                            // selection/hover updates. The
                                            // ForEach identity (LauncherItem.id)
                                            // is what scrollTo targets instead.
                                            .onHover { hovering in
                                                viewModel.setHovered(item.id, hovering: hovering)
                                            }
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
                    Text("Press ↓ for tools and recents · ⌘K for options")
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
        .onExitCommand { LauncherController.shared.handleEscape() }
    }

    private func focusActiveField() {
        if viewModel.selectedCategory == .scratchpad {
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
                viewModel.showRecentActivity()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 22)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .help("Show tools and recents (Tab or ↓)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var scratchpad: some View {
        Group {
            if viewModel.scratchpadMode == .notesList {
                notesList
                    .transition(.blurFade)
            } else {
                noteEditor
                    .transition(.blurFade)
            }
        }
        .onChange(of: viewModel.selectedCategory) { category in
            if category != .scratchpad {
                confirmDelete = false
            }
        }
        .onChange(of: viewModel.scratchpadMode) { mode in
            if mode == .notesList {
                confirmDelete = false
            }
        }
    }

    private var noteText: String {
        notesStore.currentNote?.text ?? ""
    }

    private var noteEditor: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(
                    get: { notesStore.currentNote?.text ?? "" },
                    set: { notesStore.updateCurrentNote(text: $0) }
                ))
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .frame(height: 300)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                if noteText.isEmpty {
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
                Text("⌘N New · ⌘P Notes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                if confirmDelete {
                    Text("Delete note?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button {
                        if let id = notesStore.currentNote?.id {
                            notesStore.delete(id: id)
                        }
                        confirmDelete = false
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete the note")
                    Button {
                        confirmDelete = false
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Keep the note")
                } else {
                    Button {
                        viewModel.createNote()
                    } label: {
                        Image(systemName: "plus.square")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("New note (⌘N)")

                    Button {
                        viewModel.toggleNotesList()
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("All notes (⌘P)")

                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(noteText, forType: .string)
                        showsCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showsCopied = false
                        }
                    } label: {
                        Image(systemName: showsCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(noteText.isEmpty)
                    .help(showsCopied ? "Copied" : "Copy to clipboard")
                    .opacity(noteText.isEmpty ? 0.4 : 1)

                    Button {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(noteText.isEmpty)
                    .help("Delete note")
                    .opacity(noteText.isEmpty ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var aiChatTool: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text("AI Chat is coming soon")
                .font(.system(size: 14, weight: .medium))
            Text(AppSettings.hasAIAPIKey
                 ? "Your API key is saved in Settings → Tools — the chat arrives in a future release."
                 : "Add your provider and API key in Settings → Tools, and the chat arrives in a future release.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var transformerTool: some View {
        VStack(spacing: 0) {
            switch viewModel.transformerState {
            case .capturing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Reading selection…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(24)

            case .noSelection:
                VStack(spacing: 6) {
                    Image(systemName: "textformat")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text("Nothing selected")
                        .font(.system(size: 14, weight: .medium))
                    Text("Select text in any app, then open Text Transformer")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)

            case .ready:
                if viewModel.transforms.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "textformat")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("No transformations enabled")
                            .font(.system(size: 14, weight: .medium))
                        Text("Enable them in Settings → Text Transformer")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected text")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(singleLinePreview(viewModel.transformerText))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.transforms.enumerated()), id: \.element.id) { index, transform in
                                    TransformRowView(
                                        transform: transform,
                                        preview: singleLinePreview(transform.apply(to: viewModel.transformerText)),
                                        isSelected: index == viewModel.transformSelectedIndex,
                                        isHovered: viewModel.hoveredID == transform.id
                                    )
                                    .id(transform.id)
                                    .onHover { hovering in
                                        viewModel.setHovered(transform.id, hovering: hovering)
                                    }
                                    .onTapGesture {
                                        LauncherController.shared.applySelectedTransform()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 360)
                        .onChange(of: viewModel.transformSelectedIndex) { index in
                            if let transform = viewModel.transforms[safe: index] {
                                proxy.scrollTo(transform.id, anchor: .center)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Return replaces the selection")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    /// A one-line preview of (possibly multiline) text for transformer rows.
    private func singleLinePreview(_ text: String) -> String {
        let flattened = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return String(flattened.prefix(120))
    }

    private var notesList: some View {        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(notesStore.notes.enumerated()), id: \.element.id) { index, note in
                            NoteRowView(
                                note: note,
                                isSelected: index == viewModel.notesSelectedIndex,
                                isHovered: viewModel.hoveredID == note.id.uuidString
                            )
                            .id(note.id)
                            .onHover { hovering in
                                viewModel.setHovered(note.id.uuidString, hovering: hovering)
                            }
                            .onTapGesture { viewModel.openNote(note.id) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
                .onChange(of: viewModel.notesSelectedIndex) { index in
                    if let note = notesStore.notes[safe: index] {
                        proxy.scrollTo(note.id, anchor: .center)
                    }
                }
            }

            Divider()

            HStack(spacing: 16) {
                Text("Return opens · Esc back")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    viewModel.createNote()
                } label: {
                    Image(systemName: "plus.square")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help("New note (⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var selectedID: String? {
        viewModel.filtered[safe: viewModel.selectedIndex]?.id
    }

    /// The ⌘K hint shows whenever a result row can have options — search
    /// results, category lists, and the recents view, but not the actions
    /// view or the scratchpad editor.
    private var showsOptionsFooter: Bool {
        viewModel.selectedCategory != .scratchpad
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

struct TransformRowView: View {
    let transform: TextTransform
    let preview: String
    let isSelected: Bool
    var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "textformat")
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
            Text(transform.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Text(preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .padding(.horizontal, 6)
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if isHovered { return Color.accentColor.opacity(0.10) }
        return Color.clear
    }
}

struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.excerpt.isEmpty ? "Empty note" : note.excerpt)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text(note.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .padding(.horizontal, 6)
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if isHovered { return Color.accentColor.opacity(0.10) }
        return Color.clear
    }
}

struct LauncherRowView: View {
    let item: LauncherItem
    let isSelected: Bool
    var isHovered = false
    let query: String
    let hotkeyDisplay: String?
    var canFavorite = false
    var isFavorite = false
    var onToggleFavorite: (() -> Void)? = nil

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
                .font(toolNumber != nil ? .system(size: 13, weight: .medium) : .body)
                .lineLimit(1)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let toolNumber {
                // Tools render compact in the recents view, with the same
                // ⌘-number badge the actions grid uses.
                HStack(spacing: 2) {
                    Image(systemName: "command")
                        .font(.system(size: 7, weight: .bold))
                    Text("\(toolNumber)")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
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
        .padding(.vertical, toolNumber != nil ? 6 : 9)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .padding(.horizontal, 6)
        .contextMenu {
            if canFavorite, let onToggleFavorite {
                Button(isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                    onToggleFavorite()
                }
            }
        }
    }

    /// The actions-grid number for tool rows in the recents view.
    private var toolNumber: Int? {
        if case .toolEntry(_, let number) = item { return number }
        return nil
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
