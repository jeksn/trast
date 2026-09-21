import AppKit
import CoreGraphics
import Foundation
import TrastCore

final class SnippetExpander {
    static let shared = SnippetExpander()

    /// Marks events we inject so the tap ignores its own output instead of
    /// feeding expansion text back into the keystroke buffer.
    private static let syntheticTag: Int64 = 0x5770_536E_6970
    /// Pause before deleting the keyword: lets the final physical keystroke
    /// finish so synthetic events never race real ones still in flight.
    private static let settleInterval: TimeInterval = 0.03
    /// Gap between a synthetic keyDown and its keyUp: zero-length presses get
    /// filtered as noise by some apps.
    private static let keyPressInterval: TimeInterval = 0.006
    /// Pacing between injected keystrokes: events arriving faster than a
    /// display frame (~16ms) get coalesced by apps and characters are dropped
    /// (seen as mangled expansions and keyword residue).
    private static let keystrokeInterval: TimeInterval = 0.012
    /// Pause between the backspace phase and the injection phase so the app
    /// has processed the deletions before insertions begin.
    private static let phaseInterval: TimeInterval = 0.03

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer = ""
    private var clickMonitor: Any?
    private var appChangeObserver: NSObjectProtocol?
    private let injectQueue = DispatchQueue(label: "com.trast.snippet.inject", qos: .userInteractive)
    // kCGEventSourceStatePrivate is not exposed as a Swift enum case; its raw
    // value is ~0. A private source isolates synthetic events from the shared
    // HID state so physical keys held during expansion can't suppress them.
    private let injectSource = CGEventSource(stateID: CGEventSourceStateID(rawValue: -1)!)

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
        installClickMonitor()
        observeAppChanges()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        if let appChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appChangeObserver)
        }
        eventTap = nil
        runLoopSource = nil
        clickMonitor = nil
        appChangeObserver = nil
        buffer = ""
    }

    /// Clicking into another field invalidates the typed context.
    private func installClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.buffer = ""
        }
    }

    /// Switching apps invalidates the typed context.
    private func observeAppChanges() {
        guard appChangeObserver == nil else { return }
        appChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.buffer = ""
        }
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
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticTag {
            return true
        }

        // Keystrokes landing in Trast's own UI (launcher search, settings
        // fields) never expand: editing a snippet's keyword in Settings must
        // not fire the snippet. Our panel/windows are the key window only
        // while the user is actually typing into them.
        if NSApp.keyWindow != nil {
            buffer = ""
            return true
        }

        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskAlternate) || flags.contains(.maskControl) {
            // Modified keystrokes (paste, select all, shortcuts) never produce
            // contiguous typed text.
            buffer = ""
            return true
        }

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

        // Keys that produce no text (arrows, function keys, Home/End, forward
        // delete) mean the cursor moved: the typed text is no longer contiguous.
        guard actualLength > 0 else {
            buffer = ""
            return true
        }

        let charString = String(utf16CodeUnits: chars, count: actualLength)
        guard let char = charString.first else {
            buffer = ""
            return true
        }

        if char.isWhitespace {
            buffer = ""
            return true
        }

        buffer.append(char)

        if let match = matchingSnippet() {
            buffer = ""
            expand(keyword: match.keyword, into: match.content)
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
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let resolved = SnippetTemplate.resolve(expansion, clipboardContent: clipboard)

        injectQueue.asyncAfter(deadline: .now() + Self.settleInterval) { [weak self] in
            guard let self else { return }

            for _ in 0..<keyword.count {
                self.sendBackspace()
                Thread.sleep(forTimeInterval: Self.keystrokeInterval)
            }

            Thread.sleep(forTimeInterval: Self.phaseInterval)

            for scalar in resolved.unicodeScalars {
                self.injectCharacter(scalar)
                Thread.sleep(forTimeInterval: Self.keystrokeInterval)
            }
        }
    }

    private func sendBackspace() {
        let keyDown = CGEvent(keyboardEventSource: injectSource, virtualKey: 51, keyDown: true)
        keyDown?.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
        keyDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: Self.keyPressInterval)

        let keyUp = CGEvent(keyboardEventSource: injectSource, virtualKey: 51, keyDown: false)
        keyUp?.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func injectCharacter(_ scalar: Unicode.Scalar) {
        let keyDown = CGEvent(keyboardEventSource: injectSource, virtualKey: 0, keyDown: true)
        let chars = [UniChar](scalar.utf16)
        keyDown?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        keyDown?.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
        keyDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: Self.keyPressInterval)

        let keyUp = CGEvent(keyboardEventSource: injectSource, virtualKey: 0, keyDown: false)
        keyUp?.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
        keyUp?.post(tap: .cghidEventTap)
    }
}
