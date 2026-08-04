import AppKit
import SwiftUI

/// Small floating, click-through HUD near the bottom of the screen showing
/// listening/transcribing/polishing state plus a live "what it's hearing"
/// preview — the menu bar icon alone is easy to miss while actively speaking.
@MainActor
final class HUDWindowController {
    private let panel: NSPanel
    private let model = HUDModel()

    init() {
        let hostingController = NSHostingController(rootView: HUDView(model: model))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 90),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The Dock renders above plain .floating-level windows, so a panel
        // positioned near the bottom edge can end up hidden behind it even
        // when geometrically outside visibleFrame. .statusBar sits above the
        // Dock's window level, guaranteeing the HUD stays on top of it.
        panel.level = .statusBar
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }

    func update(state: AppState) {
        model.state = state
        if state != .recording {
            model.level = 0
        }

        switch state {
        case .recording, .transcribing, .polishing:
            show()
        default:
            model.partialText = ""
            hide()
        }
    }

    func update(level: Float) {
        model.level = level
    }

    func update(partialText: String) {
        model.partialText = partialText
    }

    private func show() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = 380
        let height: CGFloat = 90
        // visibleFrame already excludes the Dock/menu bar (regardless of Dock
        // size, position, or auto-hide), so anchoring to its bottom edge keeps
        // the HUD clear of the Dock instead of guessing a fixed offset.
        let x = screen.frame.midX - width / 2
        let y = screen.visibleFrame.minY + 48
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
