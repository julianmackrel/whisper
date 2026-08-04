import SwiftUI

struct PreferencesView: View {
    @AppStorage(PolishSettingsKeys.removeFillerWords) private var removeFillerWords = PolishSettingsDefaults.removeFillerWords
    @AppStorage(PolishSettingsKeys.useBulletPoints) private var useBulletPoints = PolishSettingsDefaults.useBulletPoints
    @AppStorage(PolishSettingsKeys.formality) private var formality = PolishSettingsDefaults.formality
    @AppStorage(PolishSettingsKeys.conciseness) private var conciseness = PolishSettingsDefaults.conciseness

    var body: some View {
        Form {
            Section("Content") {
                Toggle("Remove filler words & false starts", isOn: $removeFillerWords)
                Toggle("Format as bullet points", isOn: $useBulletPoints)
            }

            Section("Tone") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Formality")
                        Spacer()
                        Text(formalityLabel).foregroundStyle(.secondary)
                    }
                    Slider(value: $formality, in: 0...1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Conciseness")
                        Spacer()
                        Text(concisenessLabel).foregroundStyle(.secondary)
                    }
                    Slider(value: $conciseness, in: 0...1)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 320)
    }

    private var formalityLabel: String {
        switch formality {
        case ..<0.34: return "Casual"
        case ..<0.67: return "Neutral"
        default: return "Professional"
        }
    }

    private var concisenessLabel: String {
        switch conciseness {
        case ..<0.34: return "Verbatim"
        case ..<0.67: return "Balanced"
        default: return "Concise"
        }
    }
}
