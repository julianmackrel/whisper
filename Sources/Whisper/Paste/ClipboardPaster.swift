import AppKit

/// Puts text on the clipboard, simulates Cmd+V into whatever app is
/// frontmost, then restores the clipboard's previous contents.
@MainActor
final class ClipboardPaster {
    private static let kVK_ANSI_V: CGKeyCode = 0x09
    private static let restoreDelay: TimeInterval = 0.35

    func pasteAndRestore(_ text: String) {
        let pasteboard = NSPasteboard.general
        let savedString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChangeCount = pasteboard.changeCount

        postCmdV()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay) {
            // Only restore if nothing else has touched the pasteboard since our write
            // (e.g. the target app read it as part of paste) — avoids clobbering a
            // clipboard change the user or another app made in the meantime.
            guard pasteboard.changeCount == ourChangeCount else { return }
            pasteboard.clearContents()
            if let savedString {
                pasteboard.setString(savedString, forType: .string)
            }
        }
    }

    private func postCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.kVK_ANSI_V, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.kVK_ANSI_V, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
