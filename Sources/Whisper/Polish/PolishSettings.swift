import Foundation

/// UserDefaults keys shared between the Preferences UI (bound via @AppStorage)
/// and FoundationModelsPolisher (read at polish time to build the prompt).
enum PolishSettingsKeys {
    static let removeFillerWords = "polish.removeFillerWords"
    static let useBulletPoints = "polish.useBulletPoints"
    static let formality = "polish.formality"
    static let conciseness = "polish.conciseness"
}

enum PolishSettingsDefaults {
    static let removeFillerWords = true
    static let useBulletPoints = false
    static let formality = 0.5
    static let conciseness = 0.5
}
