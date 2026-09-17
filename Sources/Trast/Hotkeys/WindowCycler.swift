import AppKit
import ApplicationServices
import Foundation

enum WindowCycler {
    static func cycleNext() {
        guard Accessibility.isTrusted else {
            Accessibility.openSystemSettings()
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier

        let axApp = AXUIElementCreateApplication(pid)

        guard let windows = copyValue(axApp, for: kAXWindowsAttribute as CFString) as? [AXUIElement],
              windows.count > 1 else { return }

        let current = copyValue(axApp, for: kAXMainWindowAttribute as CFString) as! AXUIElement?

        let currentIndex: Int
        if let current = current {
            currentIndex = windows.firstIndex { CFEqual($0, current) } ?? 0
        } else {
            currentIndex = 0
        }

        let nextIndex = (currentIndex + 1) % windows.count
        let nextWindow = windows[nextIndex]

        AXUIElementSetAttributeValue(axApp, kAXMainWindowAttribute as CFString, nextWindow)
        AXUIElementPerformAction(nextWindow, kAXRaiseAction as CFString)
        app.activate(options: [.activateAllWindows])
    }

    private static func copyValue(_ element: AXUIElement, for attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute, &value)
        return value
    }
}
