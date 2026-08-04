import AppKit
import Foundation
import Speech

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenuController?
    private let permissions = PermissionsCoordinator()
    private var recheckTimer: Timer?
    private let chordMonitor = ChordMonitor()
    private var dictationSession: DictationSession?
    private let polisher: PolishEngine = FoundationModelsPolisher()
    private let clipboardPaster = ClipboardPaster()
    private let preferencesWindowController = PreferencesWindowController()
    private let hud = HUDWindowController()
    private let historyStore = TranscriptHistoryStore()
    private lazy var historyWindowController = HistoryWindowController(store: historyStore)

    private func setState(_ state: AppState) {
        statusMenu?.setState(state)
        hud.update(state: state)
    }

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
        menu.onOpenPreferences = { [weak self] in
            self?.preferencesWindowController.show()
        }
        menu.onOpenHistory = { [weak self] in
            self?.historyWindowController.show()
        }

        Task {
            await permissions.bootstrapAll()
            refreshState()
            if !permissions.allGranted {
                startRecheckingUntilGranted()
            }
            warmUp()
        }

        chordMonitor.onChordDown = { [weak self] in
            guard let self, self.statusMenu?.isDictationEnabled == true else { return }
            let session = DictationSession()
            self.dictationSession = session
            session.onAudioLevel = { [weak self] level in
                self?.hud.update(level: level)
            }
            session.onPartialTranscript = { [weak self] text in
                self?.hud.update(partialText: text)
            }
            if session.start() {
                self.setState(.recording)
                SoundCue.playRecordingStart()
            } else {
                self.setState(.error)
                self.dictationSession = nil
            }
        }
        chordMonitor.onChordUp = { [weak self] in
            guard let self, let session = self.dictationSession else { return }
            self.setState(.transcribing)
            SoundCue.playRecordingEnd()
            Task {
                let transcript = await session.stop()
                // Only clear the reference if it's still *this* session. A new
                // dictation started while this one was finishing (rapid
                // release-then-press) will have replaced `dictationSession`;
                // nil-ing unconditionally here would orphan that live session.
                if self.dictationSession === session { self.dictationSession = nil }
                print("RAW: \(transcript)")

                guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.setState(.idle)
                    return
                }

                self.setState(.polishing)
                let start = Date()
                do {
                    let polished = try await self.polisher.polish(transcript)
                    let elapsed = Date().timeIntervalSince(start)
                    print("POLISHED (\(String(format: "%.2f", elapsed))s): \(polished)")
                    self.clipboardPaster.copyAndPaste(polished)
                    self.historyStore.add(rawText: transcript, polishedText: polished)
                } catch {
                    print("Polish error: \(error.localizedDescription)")
                }
                self.setState(.idle)
            }
        }
        chordMonitor.start()
    }

    /// Both SFSpeechRecognizer and FoundationModels have a noticeable one-time
    /// model-load cost on first use. Firing a throwaway pass through each
    /// right after launch keeps that latency off the user's first real
    /// dictation instead of making it feel like the app is slow to start.
    private func warmUp() {
        Task {
            let localeID = UserDefaults.standard.string(forKey: SpeechSettingsKeys.recognitionLocale)
                ?? SpeechSettingsDefaults.recognitionLocale
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)) {
                _ = recognizer.isAvailable
                _ = recognizer.supportsOnDeviceRecognition
            }
            _ = try? await polisher.polish("warm up")
        }
    }

    private func refreshState() {
        guard statusMenu?.isDictationEnabled == true else {
            setState(.disabled)
            return
        }
        setState(permissions.allGranted ? .idle : .error)
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
