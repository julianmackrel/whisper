import AppKit

/// Detects a Cmd+Ctrl modifier-only chord: down when exactly Command+Control
/// are held (no other modifiers), up when that exact set is no longer held.
@MainActor
final class ChordMonitor {
    private static let chordFlags: NSEvent.ModifierFlags = [.command, .control]

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isChordActive = false

    var onChordDown: (() -> Void)?
    var onChordUp: (() -> Void)?

    func start() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        isChordActive = false
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chordHeld = flags == Self.chordFlags

        if chordHeld && !isChordActive {
            isChordActive = true
            onChordDown?()
        } else if !chordHeld && isChordActive {
            isChordActive = false
            onChordUp?()
        }
    }
}
