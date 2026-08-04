import Foundation

struct TranscriptEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let rawText: String
    let polishedText: String

    init(id: UUID = UUID(), date: Date = Date(), rawText: String, polishedText: String) {
        self.id = id
        self.date = date
        self.rawText = rawText
        self.polishedText = polishedText
    }
}
