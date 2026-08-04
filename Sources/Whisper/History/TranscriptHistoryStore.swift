import Foundation

/// Persistent log of past dictations (raw + polished), newest first, so the
/// user can go back and copy something even if they weren't focused in a
/// text field (or just changed their mind) when it was originally dictated.
@MainActor
final class TranscriptHistoryStore: ObservableObject {
    @Published private(set) var entries: [TranscriptEntry] = []

    private static let maxEntries = 200
    private static let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Whisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    init() {
        load()
    }

    func add(rawText: String, polishedText: String) {
        entries.insert(TranscriptEntry(rawText: rawText, polishedText: polishedText), at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        entries = (try? JSONDecoder().decode([TranscriptEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
