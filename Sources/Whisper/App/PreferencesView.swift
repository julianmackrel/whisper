import AppKit
import SwiftUI

struct PreferencesView: View {
    @AppStorage(PolishSettingsKeys.removeFillerWords) private var removeFillerWords = PolishSettingsDefaults.removeFillerWords
    @AppStorage(PolishSettingsKeys.useBulletPoints) private var useBulletPoints = PolishSettingsDefaults.useBulletPoints
    @AppStorage(PolishSettingsKeys.formality) private var formality = PolishSettingsDefaults.formality
    @AppStorage(PolishSettingsKeys.conciseness) private var conciseness = PolishSettingsDefaults.conciseness
    @AppStorage(SoundSettingsKeys.recordingStartSound) private var recordingStartSound = SoundOption.defaultStart.rawValue
    @AppStorage(SoundSettingsKeys.recordingEndSound) private var recordingEndSound = SoundOption.defaultEnd.rawValue
    @AppStorage(SpeechSettingsKeys.recognitionLocale) private var recognitionLocale = SpeechSettingsDefaults.recognitionLocale

    private let availableLocales = RecognitionLocaleCatalog.availableOnDeviceLocales()

    var body: some View {
        Form {
            Section("Language") {
                Picker("Recognition language", selection: $recognitionLocale) {
                    ForEach(availableLocales) { locale in
                        Text(locale.displayName).tag(locale.identifier)
                    }
                }
                .pickerStyle(.menu)
                Text("Only languages installed for on-device Dictation appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Dictation Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Dictation") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

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

            Section("Sound") {
                SoundPickerRow(title: "Recording start sound", selection: $recordingStartSound)
                SoundPickerRow(title: "Recording end sound", selection: $recordingEndSound)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 480)
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

private struct SoundPickerRow: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        HStack {
            Picker(title, selection: $selection) {
                ForEach(SoundOption.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)

            Button {
                if let option = SoundOption(rawValue: selection) {
                    SoundCue.play(option)
                }
            } label: {
                Image(systemName: "speaker.wave.2")
            }
            .buttonStyle(.borderless)
            .disabled(selection == SoundOption.none.rawValue)
        }
    }
}
