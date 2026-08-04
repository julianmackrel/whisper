import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: TranscriptHistoryStore

    var body: some View {
        VStack(spacing: 0) {
            if store.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No transcriptions yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.entries) { entry in
                        HistoryRow(entry: entry)
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Spacer()
                Button("Clear All", role: .destructive) {
                    store.clear()
                }
                .disabled(store.entries.isEmpty)
                .padding(10)
            }
        }
        .frame(width: 460, height: 420)
    }
}

private struct HistoryRow: View {
    let entry: TranscriptEntry
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(copied ? "Copied" : "Copy") {
                    copy()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            Text(entry.polishedText)
                .font(.system(size: 13))
                .lineLimit(4)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { copy() }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.polishedText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}
