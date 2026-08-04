import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenuController?
    private let permissions = PermissionsCoordinator()
    private var recheckTimer: Timer?
    private let chordMonitor = ChordMonitor()
    private var dictationSession: DictationSession?
    private let polisher: PolishEngine = FoundationModelsPolisher()
    private let clipboardPaster = ClipboardPaster()

    func applicationDidFinishLaunching(_ notification: Notification) {
        VocabularyStore.ensureFileExists()

        let menu = StatusMenuController()
        statusMenu = menu

        menu.onToggleEnabled = { [weak self] enabled in
            if !enabled { self?.dictationSession = nil }
        }
        menu.onEditVocabulary = {
            NSWorkspace.shared.open(VocabularyStore.fileURL)
        }

        Task {
            await permissions.bootstrapAll()
            refreshState()
            if !permissions.allGranted {
                startRecheckingUntilGranted()
            }
        }

        chordMonitor.onChordDown = { [weak self] in
            guard let self, self.statusMenu?.isDictationEnabled == true else { return }
            let session = DictationSession()
            self.dictationSession = session
            if session.start() {
                self.statusMenu?.setState(.recording)
            } else {
                self.statusMenu?.setState(.error)
                self.dictationSession = nil
            }
        }
        chordMonitor.onChordUp = { [weak self] in
            guard let self, let session = self.dictationSession else { return }
            self.statusMenu?.setState(.transcribing)
            Task {
                let transcript = await session.stop()
                self.dictationSession = nil
                print("RAW: \(transcript)")

                guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.statusMenu?.setState(.idle)
                    return
                }

                self.statusMenu?.setState(.polishing)
                let start = Date()
                do {
                    let polished = try await self.polisher.polish(transcript)
                    let elapsed = Date().timeIntervalSince(start)
                    print("POLISHED (\(String(format: "%.2f", elapsed))s): \(polished)")
                    self.clipboardPaster.pasteAndRestore(polished)
                } catch {
                    print("Polish error: \(error.localizedDescription)")
                }
                self.statusMenu?.setState(.idle)
            }
        }
        chordMonitor.start()
    }

    private func refreshState() {
        guard statusMenu?.isDictationEnabled == true else {
            statusMenu?.setState(.disabled)
            return
        }
        statusMenu?.setState(permissions.allGranted ? .idle : .error)
    }

    /// Permission grants made in System Settings (Accessibility in particular)
    /// happen out-of-band with no in-app callback, so poll until they land.
    private func startRecheckingUntilGranted() {
        recheckTimer?.invalidate()
        recheckTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshState()
                if self.permissions.allGranted {
                    self.recheckTimer?.invalidate()
                    self.recheckTimer = nil
                }
            }
        }
    }
}
