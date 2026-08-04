import AVFoundation
import Speech

/// One push-to-talk recording+transcription session. Not reused across
/// presses — a fresh instance is created per chord-down.
@MainActor
final class DictationSession {
    private let audioEngine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var finalContinuation: CheckedContinuation<String, Never>?
    private var isRunning = false

    /// Starts capturing mic audio and streaming it to on-device recognition.
    /// Returns false if the recognizer/engine couldn't start.
    func start() -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            print("Speech recognizer unavailable")
            return false
        }
        guard recognizer.supportsOnDeviceRecognition else {
            print("On-device recognition not supported for this locale")
            return false
        }

        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = VocabularyStore.load()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.latestTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.resolveFinal()
                    }
                }
                if let error {
                    print("Recognition error: \(error.localizedDescription)")
                    self.resolveFinal()
                }
            }
        }

        // Captured as a plain local (not via `self`) since this closure fires on a
        // realtime CoreAudio thread — touching a @MainActor-isolated property here
        // would trip Swift 6's actor-isolation runtime check and crash.
        let tapRequest = request
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            tapRequest.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            return false
        }

        isRunning = true
        return true
    }

    /// Stops capture and waits briefly for a final transcript, falling back
    /// to the best partial result if the recognizer doesn't finalize quickly.
    func stop() async -> String {
        guard isRunning else { return latestTranscript }
        isRunning = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request.endAudio()

        let transcript = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            finalContinuation = continuation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.resolveFinal()
            }
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        return transcript
    }

    private func resolveFinal() {
        guard let continuation = finalContinuation else { return }
        finalContinuation = nil
        continuation.resume(returning: latestTranscript)
    }
}
