import AppKit
import Foundation
import TrastCore

final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: DispatchSourceTimer?
    private var lastChangeCount: Int

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard AppSettings.clipboardEnabled else { return }
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: 0.5)
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let item = readItem(from: pasteboard) {
            DispatchQueue.main.async {
                ClipboardStore.shared.add(item)
            }
        }
    }

    private func readItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        let types = pasteboard.types ?? []

        if types.contains(.fileURL) {
            if let url = pasteboard.string(forType: .fileURL).flatMap(URL.init(fileURLWithPath:)) {
                let urlString = url.absoluteString
                return ClipboardItem(kind: .fileURL, fileURLString: urlString)
            }
        }

        if types.contains(.tiff) || types.contains(.png) {
            if let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
                return ClipboardItem(kind: .image, imageData: data)
            }
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ClipboardItem(kind: .text, textContent: text)
        }

        return nil
    }
}
