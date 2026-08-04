import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController {
    convenience init(store: TranscriptHistoryStore) {
        let hosting = NSHostingController(rootView: HistoryView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Whisper History"
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
