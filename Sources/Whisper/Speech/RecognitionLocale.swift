import Foundation
import Speech

enum SpeechSettingsKeys {
    static let recognitionLocale = "speech.recognitionLocaleIdentifier"
}

enum SpeechSettingsDefaults {
    static let recognitionLocale = "en_US"
}

struct RecognitionLocale: Identifiable, Hashable {
    let identifier: String
    let displayName: String
    var id: String { identifier }
}

enum RecognitionLocaleCatalog {
    /// Locales actually usable for on-device recognition on this Mac right
    /// now — depends on which dictation languages the user has installed
    /// (System Settings > Keyboard > Dictation), so this can't be hardcoded
    /// and is computed at runtime.
    static func availableOnDeviceLocales() -> [RecognitionLocale] {
        let current = Locale(identifier: SpeechSettingsDefaults.recognitionLocale)
        let onDevice = SFSpeechRecognizer.supportedLocales().filter { locale in
            SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition == true
        }
        var seen = Set<String>()
        return onDevice
            .compactMap { locale -> RecognitionLocale? in
                guard seen.insert(locale.identifier).inserted else { return nil }
                let name = current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
                return RecognitionLocale(identifier: locale.identifier, displayName: name)
            }
            .sorted { $0.displayName < $1.displayName }
    }
}
