import AppKit
import SwiftUI
import WindowPaneCore

struct ClipboardSection: Identifiable {
    let title: String
    let items: [ClipboardItem]
    var id: String { title }
}

final class ClipboardViewModel: ObservableObject {
    @Published var query = "" {
        didSet { selectedIndex = 0 }
    }
    @Published var selectedIndex = 0
    @Published var focusToken = UUID()

    var items: [ClipboardItem] {
        ClipboardStore.shared.items
    }

    func reset() {
        query = ""
        selectedIndex = 0
        focusToken = UUID()
    }

    var filtered: [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let all = items
        guard !trimmed.isEmpty else { return all }
        return all.filter { item in
            switch item.kind {
            case .text:
                return (item.textContent ?? "").localizedCaseInsensitiveContains(trimmed)
            case .fileURL:
                return (item.fileURLString ?? "").localizedCaseInsensitiveContains(trimmed)
            case .image:
                return false
            }
        }
    }

    var sections: [ClipboardSection] {
        let filtered = self.filtered
        return ["Text", "Images", "Files"].compactMap { title in
            let kind: ClipboardItem.Kind
            switch title {
            case "Text": kind = .text
            case "Images": kind = .image
            case "Files": kind = .fileURL
            default: return nil
            }
            let sectionItems = filtered.filter { $0.kind == kind }
            return sectionItems.isEmpty ? nil : ClipboardSection(title: title, items: sectionItems)
        }
    }

    func moveSelection(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    func selectedItem() -> ClipboardItem? {
        filtered[safe: selectedIndex]
    }
}

struct ClipboardView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @ObservedObject var store: ClipboardStore
    let onSelect: (ClipboardItem) -> Void
    let onPin: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard history", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($isFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if viewModel.filtered.isEmpty {
                Text("No clipboard history")
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
                                    ClipboardRowView(
                                        item: item,
                                        isSelected: item.id == viewModel.selectedItem()?.id,
                                        onTap: { onSelect(item) },
                                        onPin: { onPin(item) },
                                        onDelete: { onDelete(item) }
                                    )
                                    .id(item.id)
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
        .onExitCommand { ClipboardController.shared.close() }
    }
}

struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onTap: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .lineLimit(1)
                if item.kind == .text {
                    Text(item.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if item.kind == .fileURL {
                    Text(item.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.pinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 11))
            }

            Text(timeAgo(item.timestamp))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .contextMenu {
            Button(item.pinned ? "Unpin" : "Pin") { onPin() }
            Button("Delete") { onDelete() }
        }
        .onAppear { loadThumbnail() }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if isHovered { return Color.accentColor.opacity(0.10) }
        return Color.clear
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.kind {
        case .text:
            Image(systemName: "text.alignleft")
                .foregroundStyle(.secondary)
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        case .fileURL:
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }

    private func loadThumbnail() {
        guard item.kind == .image, let data = item.imageData, thumbnail == nil else { return }
        DispatchQueue.global(qos: .utility).async {
            let image = NSImage(data: data)
            DispatchQueue.main.async {
                thumbnail = image
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
