import AppKit
import SwiftUI
import CoreGraphics

final class ClipboardController: NSObject, NSWindowDelegate {
    static let shared = ClipboardController()

    private var panel: ClipboardPanel?
    private let viewModel = ClipboardViewModel()
    private var keyMonitor: Any?

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        viewModel.reset()
        let panel = ensurePanel()
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> ClipboardPanel {
        if let panel { return panel }

        let panel = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: ClipboardView(
                viewModel: viewModel,
                store: ClipboardStore.shared,
                onSelect: { [weak self] item in self?.handleSelect(item) },
                onPin: { ClipboardStore.shared.togglePin($0) },
                onDelete: { ClipboardStore.shared.remove($0) }
            )
        )
        self.panel = panel
        installKeyMonitor()
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - panel.frame.width / 2
        let y = visible.maxY - visible.height * 0.32 - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow else { return event }
            switch event.keyCode {
            case 125:
                self.viewModel.moveSelection(1)
                return nil
            case 126:
                self.viewModel.moveSelection(-1)
                return nil
            case 36, 76:
                if let item = self.viewModel.selectedItem() {
                    self.handleSelect(item)
                }
                return nil
            case 53:
                self.close()
                return nil
            case 51:
                if let item = self.viewModel.selectedItem() {
                    ClipboardStore.shared.remove(item)
                }
                return nil
            default:
                return event
            }
        }
    }

    private func handleSelect(_ item: ClipboardItem) {
        close()
        paste(item)
    }

    private func paste(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .tiff)
            }
        case .fileURL:
            if let url = item.fileURL {
                pasteboard.writeObjects([url as NSURL])
            }
        }

        postCmdV()
    }

    private func postCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
