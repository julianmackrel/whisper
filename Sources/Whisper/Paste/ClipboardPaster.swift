import AppKit

/// Puts text on the clipboard and simulates Cmd+V into whatever app is
/// frontmost. The text is deliberately left on the clipboard afterward
/// (not restored) — if nothing was focused to receive the paste, the user
/// can still Cmd+V it manually at any point.
@MainActor
final class ClipboardPaster {
    private static let kVK_ANSI_V: CGKeyCode = 0x09

    func copyAndPaste(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postCmdV()
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
