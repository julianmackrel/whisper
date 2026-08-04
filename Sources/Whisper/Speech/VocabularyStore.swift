import Foundation

/// User-editable list of custom words/phrases (names, jargon, product terms)
/// fed into SFSpeechRecognitionRequest.contextualStrings to bias recognition.
enum VocabularyStore {
    static let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Whisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vocabulary.txt")
    }()

    static func ensureFileExists() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let template = """
        # Add custom words or phrases below, one per line — names, jargon, product
        # terms that speech recognition tends to mis-hear. Lines starting with #
        # are ignored. Changes take effect on your next dictation.

        """
        try? template.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func load() -> [String] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return contents
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}
