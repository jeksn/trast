import WindowPaneCore
import AppKit

final class CommandApplier {
    static let shared = CommandApplier()

    private let restoreStore = RestoreStore.shared

    func apply(_ command: WindowCommand, target: WindowRef? = nil) {
        guard Accessibility.ensureTrusted(prompt: true) else {
            HUD.show("Enable Accessibility in System Settings")
            return
        }
        guard let target = target ?? WindowManipulator.frontmostWindow() else {
            HUD.show("No focused window")
            return
        }
        guard let currentFrame = WindowManipulator.frame(of: target.window) else {
            HUD.show("Could not read window geometry")
            return
        }

        if command.id == WindowAction.nextDisplay.commandID {
            moveToNextDisplay(target: target, currentFrame: currentFrame)
            return
        }

        guard let screen = WindowManipulator.screen(containing: currentFrame) else {
            HUD.show("Could not detect display")
            return
        }

        let usable = LayoutEngine.usableArea(in: screen.visibleFrame, gap: CGFloat(AppSettings.gap))
        let newFrame = LayoutEngine.frame(for: LayoutEngine.Request(
            usableArea: usable,
            currentFrame: currentFrame,
            width: command.width,
            height: command.height,
            anchor: command.anchor,
            offsetX: command.offsetX,
            offsetY: command.offsetY,
            interGap: CGFloat(AppSettings.gap)
        ))

        restoreStore.record(key: target.restoreKey, frame: currentFrame)

        if let error = WindowManipulator.setFrame(target, to: newFrame) {
            HUD.show("Could not resize window (\(error.rawValue))")
        }
    }

    private func moveToNextDisplay(target: WindowRef, currentFrame: CGRect) {
        guard let currentScreen = WindowManipulator.screen(containing: currentFrame) else {
            HUD.show("Could not detect display")
            return
        }
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            HUD.show("Only one display connected")
            return
        }
        guard let currentIndex = screens.firstIndex(of: currentScreen) else {
            HUD.show("Could not detect display")
            return
        }
        let nextScreen = screens[(currentIndex + 1) % screens.count]
        let currentUsable = LayoutEngine.usableArea(in: currentScreen.visibleFrame, gap: CGFloat(AppSettings.gap))
        let nextUsable = LayoutEngine.usableArea(in: nextScreen.visibleFrame, gap: CGFloat(AppSettings.gap))
        let newFrame = LayoutEngine.frameForNextDisplay(
            currentFrame: currentFrame,
            currentUsable: currentUsable,
            nextUsable: nextUsable
        )

        restoreStore.record(key: target.restoreKey, frame: currentFrame)

        if let error = WindowManipulator.setFrame(target, to: newFrame) {
            HUD.show("Could not move window (\(error.rawValue))")
        }
    }

    func restore(target: WindowRef? = nil) {
        guard Accessibility.ensureTrusted(prompt: true) else {
            HUD.show("Enable Accessibility in System Settings")
            return
        }
        guard let target = target ?? WindowManipulator.frontmostWindow() else {
            HUD.show("No focused window")
            return
        }
        guard let currentFrame = WindowManipulator.frame(of: target.window) else {
            HUD.show("Could not read window geometry")
            return
        }
        guard let previousFrame = restoreStore.frame(for: target.restoreKey) else {
            HUD.show("Nothing to restore")
            return
        }

        restoreStore.record(key: target.restoreKey, frame: currentFrame)

        if let error = WindowManipulator.setFrame(target, to: previousFrame) {
            HUD.show("Could not restore window (\(error.rawValue))")
        }
    }
}
