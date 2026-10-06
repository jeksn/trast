import TrastCore
import SwiftUI
import AppKit

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let onSelect: (LauncherItem) -> Void
    @ObservedObject private var notesStore = NotesStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var chatStore = ChatStore.shared

    @FocusState private var isFocused: Bool
    @FocusState private var editorFocused: Bool
    @FocusState private var chatFocused: Bool

    @State private var showsCopied = false
    @State private var confirmDelete = false
    @State private var chatInput = ""
    @State private var chatSending = false
    @State private var chatError: String?
    @State private var chatHasKey = false
    @State private var chatCopied = false

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
                                            viewModel: viewModel,
                                            item: item,
                                            query: viewModel.query,
                                            hotkeyDisplay: viewModel.hotkeyDisplay(for: item),
                                            canFavorite: viewModel.isFavoritable(item),
                                            isFavorite: viewModel.isFavorite(item),
                                            onToggleFavorite: { viewModel.toggleFavorite(item.id) }
                                        )
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
                // Dark mode uses the thicker material - genuinely darker
                // (Spotlight-like) while keeping its own translucency.
                // Light mode stays on the regular material; a darkening
                // overlay there read as flat grey and killed the
                // see-through effect in both modes.
                .fill(colorScheme == .dark ? .thickMaterial : .regularMaterial)
                .opacity(AppSettings.launcherSlightTransparency ? 0.85 : 1.0)
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
        } else if viewModel.selectedCategory == .aiChat {
            chatFocused = true
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
        Group {
            if viewModel.chatMode == .history {
                chatHistoryList
            } else if chatHasKey {
                VStack(spacing: 0) {
                    chatHeader
                    Divider()
                    chatMessages
                    if let chatError {
                        Divider()
                        Text(chatError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    chatInputRow
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text("AI Chat")
                        .font(.system(size: 14, weight: .medium))
                    Text("Add your provider and API key in Settings → AI Chat to start chatting.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { chatHasKey = APIKeyStore.read() != nil }
        .onChange(of: viewModel.focusToken) { _ in
            // Settings may have changed while the panel was closed.
            chatHasKey = APIKeyStore.read() != nil
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Text(chatStore.currentDiscussion?.title ?? "New chat")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if !chatStore.currentMessages.isEmpty {
                Button {
                    copyTranscript()
                } label: {
                    Image(systemName: chatCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help(chatCopied ? "Copied" : "Copy the whole discussion")
            }

            Button {
                viewModel.createNewChatDiscussion()
                chatError = nil
            } label: {
                Image(systemName: "plus.square")
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help("New discussion (⌘N)")

            Button {
                viewModel.toggleChatHistory()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Previous discussions (⌘P)")

            Button {
                viewModel.chatExpanded.toggle()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help(viewModel.chatExpanded ? "Compact view" : "Expand for longer conversations")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// The previous-discussions list — the same shape as the Scratchpad's
    /// notes list, not a modal.
    private var chatHistoryList: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if chatStore.discussions.isEmpty {
                            Text("No discussions yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(16)
                        }
                        ForEach(Array(chatStore.discussions.enumerated()), id: \.element.id) { index, discussion in
                            ChatDiscussionRowView(
                                discussion: discussion,
                                isSelected: index == viewModel.chatSelectedIndex,
                                isHovered: viewModel.hoveredID == discussion.id.uuidString,
                                onDelete: { viewModel.deleteDiscussion(at: index) }
                            )
                            .id(discussion.id)
                            .onHover { hovering in
                                viewModel.setHovered(discussion.id.uuidString, hovering: hovering)
                            }
                            .onTapGesture { viewModel.openSelectedDiscussionID(discussion.id) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
                .onChange(of: viewModel.chatSelectedIndex) { index in
                    if let discussion = chatStore.discussions[safe: index] {
                        proxy.scrollTo(discussion.id, anchor: .center)
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
                    viewModel.createNewChatDiscussion()
                } label: {
                    Image(systemName: "plus.square")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help("New discussion (⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func copyTranscript() {
        let transcript = chatStore.currentMessages
            .map { ($0.role == .user ? "You: " : "AI: ") + $0.text }
            .joined(separator: "\n\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
        chatCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            chatCopied = false
        }
    }

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(chatStore.currentMessages.enumerated()), id: \.offset) { index, message in
                        ChatBubbleView(message: message)
                            .id(index)
                    }
                    if chatSending {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .id("thinking")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            // Fixed at the normal size when compact (an empty chat keeps the
            // panel launcher-sized instead of collapsing), ~80% of the
            // viewport when expanded.
            .frame(minHeight: 280, maxHeight: viewModel.chatExpanded ? chatExpandedHeight : 280)
            .onChange(of: chatStore.discussions) { _ in
                scrollToBottom(proxy)
            }
            .onAppear {
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if chatSending {
            proxy.scrollTo("thinking", anchor: .bottom)
        } else {
            proxy.scrollTo(max(chatStore.currentMessages.count - 1, 0), anchor: .bottom)
        }
    }

    /// ~80% of the viewport, minus the chat chrome (header + input + error).
    private var chatExpandedHeight: CGFloat {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return visible.height * 0.8 - 130
    }

    private var chatInputRow: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $chatInput)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($chatFocused)
                .onSubmit(sendChatMessage)
            Button {
                sendChatMessage()
            } label: {
                if chatSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane")
                        .foregroundStyle(chatInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .disabled(chatSending || chatInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .help("Send (Return)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sendChatMessage() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chatSending else { return }
        chatError = nil
        chatInput = ""
        chatStore.appendToCurrent(ChatMessage(role: .user, text: text))
        chatSending = true
        let messages = chatStore.currentMessages
        Task { @MainActor in
            do {
                let reply = try await ChatService.send(messages: messages)
                chatStore.appendToCurrent(ChatMessage(role: .assistant, text: reply))
            } catch {
                chatError = error.localizedDescription
            }
            chatSending = false
        }
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

extension Date {
    /// "Oct 3" for the current year, "Oct 3, 2025" otherwise — the plain
    /// date for list rows, instead of relative "2 hours ago" text.
    var rowDateLabel: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.component(.year, from: self) == calendar.component(.year, from: Date()) {
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        }
        return formatter.string(from: self)
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage

    @State private var isHovered = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 48) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(message.role == .user
                                  ? Color.accentColor.opacity(0.25)
                                  : Color.secondary.opacity(0.12))
                    )
                    .lineLimit(nil)
                if message.role == .assistant, isHovered {
                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(message.text, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(copied ? "Copied" : "Copy reply")
                }
            }
            if message.role == .assistant { Spacer(minLength: 48) }
        }
        .onHover { isHovered = $0 }
    }
}

struct ChatDiscussionRowView: View {
    let discussion: ChatDiscussion
    let isSelected: Bool
    var isHovered = false
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(discussion.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text(discussion.updatedAt.rowDateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete discussion")
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
                Text(note.updatedAt.rowDateLabel)
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
    // The row observes the view model itself and derives isSelected/isHovered
    // from it: rows that moved between sections (favorites -> search results)
    // get reused by the LazyVStack under the same ForEach id, and a reused
    // row silently stops painting INPUT-driven changes on this macOS version.
    // A view that self-invalidates on every model change can't go stale.
    @ObservedObject var viewModel: LauncherViewModel
    let item: LauncherItem
    let query: String
    let hotkeyDisplay: String?
    var canFavorite = false
    var isFavorite = false
    var onToggleFavorite: (() -> Void)? = nil

    private var isSelected: Bool {
        viewModel.filtered[safe: viewModel.selectedIndex]?.id == item.id
    }

    private var isHovered: Bool {
        viewModel.hoveredID == item.id
    }

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
