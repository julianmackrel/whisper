import AppKit
import Foundation

enum SoundCue {
    static func playRecordingStart() {
        playStored(key: SoundSettingsKeys.recordingStartSound, fallback: .defaultStart)
    }

    static func playRecordingEnd() {
        playStored(key: SoundSettingsKeys.recordingEndSound, fallback: .defaultEnd)
    }

    static func play(_ option: SoundOption) {
        guard let name = option.soundName else { return }
        NSSound(named: name)?.play()
    }

    private static func playStored(key: String, fallback: SoundOption) {
        let stored = UserDefaults.standard.string(forKey: key) ?? fallback.rawValue
        play(SoundOption(rawValue: stored) ?? fallback)
    }
}
