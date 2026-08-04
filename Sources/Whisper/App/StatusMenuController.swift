import AppKit

enum AppState: String {
    case idle = "Idle"
    case recording = "Recording…"
    case transcribing = "Transcribing…"
    case polishing = "Polishing…"
    case error = "Error"
    case disabled = "Disabled"

    var symbolName: String {
        switch self {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing, .polishing: return "waveform"
        case .error: return "exclamationmark.triangle"
        case .disabled: return "mic.slash"
        }
    }
}

@MainActor
final class StatusMenuController {
    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem
    private let enabledMenuItem: NSMenuItem
    private let launchAtLoginMenuItem: NSMenuItem
    private(set) var state: AppState = .idle {
        didSet { render() }
    }

    /// Whether dictation (the hotkey) is active. Distinct from `state`, which
    /// reflects the current phase of an in-flight dictation.
    var isDictationEnabled = true

    var onToggleEnabled: ((Bool) -> Void)?
    var onEditVocabulary: (() -> Void)?
    var onOpenPreferences: (() -> Void)?
    var onOpenHistory: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusMenuItem = NSMenuItem(title: AppState.idle.rawValue, action: nil, keyEquivalent: "")
        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        let editVocabularyItem = NSMenuItem(title: "Edit Custom Words…", action: #selector(editVocabulary), keyEquivalent: "")
        let historyItem = NSMenuItem(title: "History…", action: #selector(openHistory), keyEquivalent: "h")
        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        let quitItem = NSMenuItem(title: "Quit Whisper", action: #selector(quit), keyEquivalent: "q")

        let menu = NSMenu()
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(enabledMenuItem)
        menu.addItem(launchAtLoginMenuItem)
        menu.addItem(editVocabularyItem)
        menu.addItem(historyItem)
        menu.addItem(preferencesItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu

        for item in menu.items {
            item.target = self
        }

        enabledMenuItem.state = .on
        launchAtLoginMenuItem.state = LoginItemManager.isEnabled ? .on : .off

        render()
    }

    func setState(_ newState: AppState) {
        state = newState
    }

    private func render() {
        statusItem.button?.image = NSImage(
            systemSymbolName: state.symbolName,
            accessibilityDescription: state.rawValue
        )
        statusMenuItem.title = "Status: \(state.rawValue)"
    }

    @objc private func toggleEnabled() {
        isDictationEnabled.toggle()
        enabledMenuItem.state = isDictationEnabled ? .on : .off
        onToggleEnabled?(isDictationEnabled)
        setState(isDictationEnabled ? .idle : .disabled)
    }

    @objc private func toggleLaunchAtLogin() {
        let newValue = LoginItemManager.isEnabled == false
        LoginItemManager.setEnabled(newValue)
        launchAtLoginMenuItem.state = LoginItemManager.isEnabled ? .on : .off
    }

    @objc private func editVocabulary() {
        onEditVocabulary?()
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }

    @objc private func openHistory() {
        onOpenHistory?()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
