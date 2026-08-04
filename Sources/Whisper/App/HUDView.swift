import SwiftUI

@MainActor
final class HUDModel: ObservableObject {
    @Published var state: AppState = .idle
    @Published var level: Float = 0
    @Published var partialText: String = ""
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                indicator
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }

            if !model.partialText.isEmpty {
                Text(model.partialText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: 340, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 360, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var label: String {
        switch model.state {
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .polishing: return "Polishing…"
        default: return ""
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch model.state {
        case .recording:
            WaveformView(level: model.level)
        case .transcribing, .polishing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        default:
            EmptyView()
        }
    }
}

/// A small live bar waveform driven by the mic's current input level —
/// keeps a short rolling history so it reads as motion, not a static meter.
private struct WaveformView: View {
    let level: Float

    private static let barCount = 5
    @State private var samples: [CGFloat] = Array(repeating: 0, count: WaveformView.barCount)

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(samples.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.red)
                    .frame(width: 3, height: barHeight(samples[i]))
            }
        }
        .frame(height: 20)
        .onChange(of: level) { _, newLevel in
            samples.removeFirst()
            samples.append(normalize(newLevel))
        }
    }

    private func normalize(_ level: Float) -> CGFloat {
        // Mic RMS for normal speech sits roughly in 0.005...0.05 — scale and
        // clamp so typical speech visibly moves the bars.
        CGFloat(min(max(level * 12, 0), 1))
    }

    private func barHeight(_ sample: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        return minHeight + sample * (maxHeight - minHeight)
    }
}
