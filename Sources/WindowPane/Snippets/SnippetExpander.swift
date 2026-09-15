import AppKit
import CoreGraphics
import Foundation
import WindowPaneCore

final class SnippetExpander {
    static let shared = SnippetExpander()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer = ""

    private init() {}

    var isRunning: Bool { eventTap != nil }

    func start() {
        guard AppSettings.snippetsEnabled else { return }
        guard eventTap == nil else { return }
        guard ensureInputMonitoringPermission() else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, _, event, userInfo in
            guard let userInfo else { return Unmanaged.passRetained(event) }
            let expander = Unmanaged<SnippetExpander>.fromOpaque(userInfo).takeUnretainedValue()
            return expander.handleEvent(event) ? Unmanaged.passRetained(event) : nil
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        buffer = ""
    }

    func restart() {
        stop()
        start()
    }

    private func ensureInputMonitoringPermission() -> Bool {
        if CGPreflightListenEventAccess() { return true }
        CGRequestListenEventAccess()
        return CGPreflightListenEventAccess()
    }

    private func handleEvent(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch keyCode {
        case 36, 76:
            buffer = ""
            return true
        case 53:
            buffer = ""
            return true
        case 48:
            buffer = ""
            return true
        case 49:
            buffer = ""
            return true
        case 51:
            if !buffer.isEmpty { buffer.removeLast() }
            return true
        default:
            break
        }

        var actualLength: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let maxLen = chars.count
        event.keyboardGetUnicodeString(maxStringLength: maxLen, actualStringLength: &actualLength, unicodeString: &chars)

        guard actualLength > 0 else { return true }

        let charString = String(utf16CodeUnits: chars, count: actualLength)
        guard let char = charString.first else { return true }

        if char.isWhitespace {
            buffer = ""
            return true
        }

        buffer.append(char)

        if let match = matchingSnippet() {
            let keyword = match.keyword
            buffer = ""
            DispatchQueue.main.async { [weak self] in
                self?.expand(keyword: keyword, into: match.content)
            }
        }

        return true
    }

    private func matchingSnippet() -> Snippet? {
        let snippets = SnippetStore.shared.validSnippets
        for snippet in snippets where snippet.keyword == buffer {
            return snippet
        }
        return nil
    }

    private func expand(keyword: String, into expansion: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<keyword.count {
            sendBackspace(source: source)
        }

        for scalar in expansion.unicodeScalars {
            injectCharacter(scalar, source: source)
        }
    }

    private func sendBackspace(source: CGEventSource?) {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func injectCharacter(_ scalar: Unicode.Scalar, source: CGEventSource?) {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let chars = [UniChar](scalar.utf16)
        keyDown?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        keyUp?.post(tap: .cghidEventTap)
    }
}
