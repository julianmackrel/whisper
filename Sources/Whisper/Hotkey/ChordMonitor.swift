import AppKit

/// Detects a Cmd+Ctrl modifier-only chord: down when exactly Command+Control
/// are held (no other modifiers), up when that exact set is no longer held.
@MainActor
final class ChordMonitor {
    private static let chordFlags: NSEvent.ModifierFlags = [.command, .control]
    /// Grace period before treating a release as real, so a momentary key
    /// blip (e.g. Control lifting for an instant as your hand shifts) doesn't
    /// split one held dictation into several separate presses.
    private static let releaseDebounce: TimeInterval = 0.2

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isChordActive = false
    private var pendingRelease: DispatchWorkItem?

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
        pendingRelease?.cancel()
        pendingRelease = nil
        isChordActive = false
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chordHeld = flags == Self.chordFlags

        if chordHeld {
            pendingRelease?.cancel()
            pendingRelease = nil
            if !isChordActive {
                isChordActive = true
                onChordDown?()
            }
        } else if isChordActive {
            pendingRelease?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.isChordActive else { return }
                self.isChordActive = false
                self.pendingRelease = nil
                self.onChordUp?()
            }
            pendingRelease = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.releaseDebounce, execute: workItem)
        }
    }
}
