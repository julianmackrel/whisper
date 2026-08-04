import Foundation

enum SoundSettingsKeys {
    static let recordingStartSound = "sound.recordingStartName"
    static let recordingEndSound = "sound.recordingEndName"
}

/// The standard set of short system sounds bundled in /System/Library/Sounds.
enum SoundOption: String, CaseIterable, Identifiable {
    case none = "None"
    case basso = "Basso"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case glass = "Glass"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case tink = "Tink"

    var id: String { rawValue }
    var displayName: String { rawValue }
    /// The name to pass to `NSSound(named:)` — nil means "play nothing".
    var soundName: String? { self == .none ? nil : rawValue }

    static let defaultStart: SoundOption = .glass
    static let defaultEnd: SoundOption = .tink
}
