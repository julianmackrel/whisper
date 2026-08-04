import AVFoundation
import Speech

/// Thread-safe holder for the "current" recognition request. The audio tap
/// (fires on a realtime CoreAudio thread) always appends to whatever request
/// is current; MainActor code swaps it out during segment rotation.
private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var current: SFSpeechAudioBufferRecognitionRequest

    init(_ request: SFSpeechAudioBufferRecognitionRequest) {
        current = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = current
        lock.unlock()
        request.append(buffer)
    }

    func swap(_ newRequest: SFSpeechAudioBufferRecognitionRequest) -> SFSpeechAudioBufferRecognitionRequest {
        lock.lock()
        let old = current
        current = newRequest
        lock.unlock()
        return old
    }

    func currentRequest() -> SFSpeechAudioBufferRecognitionRequest {
        lock.lock()
        let request = current
        lock.unlock()
        return request
    }
}

/// One push-to-talk recording+transcription session. Not reused across
/// presses — a fresh instance is created per chord-down.
///
/// Apple's on-device recognizer has a limited context window: left running
/// on a single request for a long utterance, it can silently drop earlier
/// content and only return the most recent portion. It also finalizes a
/// request on its own after a pause in speech. To handle both, this "rotates"
/// — ending the current recognition request and starting a fresh one on the
/// same continuous audio stream — either periodically (long continuous
/// speech) or immediately whenever a segment ends on its own (e.g. a pause),
/// concatenating each segment's finalized text as it goes.
@MainActor
final class DictationSession {
    /// Rotation is driven by *our own* silence detection, not the recognizer's
    /// finalization signal — the recognizer can apparently reset its hypothesis
    /// mid-task after a pause without ever calling back with `isFinal`/`error`,
    /// silently discarding everything said before the pause. Watching our own
    /// audio level and proactively committing+restarting the moment we see a
    /// pause avoids ever depending on that. A hard cap still applies in case
    /// the user never pauses, to avoid the on-device context-window limit.
    private static let maxSegmentDuration: TimeInterval = 25
    private static let silenceLevelThreshold: Float = 0.006
    private static let silenceRotateDelay: TimeInterval = 0.6
    private static let minSegmentDurationBeforeSilenceRotate: TimeInterval = 1.5
    private static let rotationCheckInterval: TimeInterval = 0.2

    private let audioEngine = AVAudioEngine()
    private var requestBox: RequestBox?
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var segmentTimer: Timer?
    private var segmentStartTime = Date()
    private var recentLevel: Float = 0
    private var quietSince: Date?

    private var committedTranscript = ""
    private var segmentTranscripts: [UUID: String] = [:]
    private var currentSegmentID: UUID?
    private var finishingSegmentID: UUID?

    private var finalContinuation: CheckedContinuation<String, Never>?
    private var isRunning = false

    /// Fires ~every audio buffer (dozens of times/sec) with the current input
    /// level (0...1-ish), for driving a live waveform indicator.
    var onAudioLevel: ((Float) -> Void)?

    /// Fires whenever the live transcript-so-far changes (partial or final),
    /// for driving a live "what it's hearing" preview.
    var onPartialTranscript: ((String) -> Void)?

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
        self.recognizer = recognizer

        let request = makeRequest()
        let box = RequestBox(request)
        requestBox = box
        startRecognitionTask(with: request)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [weak self] buffer, _ in
            box.append(buffer)
            let level = Self.rmsLevel(buffer)
            Task { @MainActor in
                self?.recentLevel = level
                self?.onAudioLevel?(level)
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            return false
        }

        isRunning = true
        scheduleSegmentRotation()
        return true
    }

    /// Stops capture and waits briefly for the final segment to resolve,
    /// falling back to whatever's been collected so far if it doesn't
    /// finalize quickly.
    func stop() async -> String {
        guard isRunning else { return committedTranscript }
        isRunning = false
        segmentTimer?.invalidate()
        segmentTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        finishingSegmentID = currentSegmentID
        requestBox?.currentRequest().endAudio()

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

    nonisolated private static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        return sqrt(sum / Float(frameLength))
    }

    private func makeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = VocabularyStore.load()
        return request
    }

    private func startRecognitionTask(with request: SFSpeechAudioBufferRecognitionRequest) {
        guard let recognizer else { return }
        let segmentID = UUID()
        currentSegmentID = segmentID
        segmentTranscripts[segmentID] = ""
        segmentStartTime = Date()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.handle(segmentID: segmentID, result: result, error: error)
            }
        }
    }

    private func handle(segmentID: UUID, result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            segmentTranscripts[segmentID] = result.bestTranscription.formattedString
            publishLivePreview()
            if result.isFinal {
                segmentEnded(segmentID)
            }
        }
        if error != nil {
            // Errors like "No speech detected" fire routinely for short trailing
            // segments during rotation — not fatal, just close out this segment.
            segmentEnded(segmentID)
        }
    }

    private func publishLivePreview() {
        guard let currentSegmentID, let currentText = segmentTranscripts[currentSegmentID] else { return }
        let preview = committedTranscript.isEmpty ? currentText : committedTranscript + " " + currentText
        onPartialTranscript?(preview)
    }

    /// A segment's task has ended — either because we explicitly rotated/stopped
    /// it, or because the recognizer's own silence detection finalized it on its
    /// own (e.g. the user paused mid-thought). In the latter case `segmentID`
    /// will still be `currentSegmentID` (nothing has replaced it yet), and we
    /// must start a fresh segment immediately — otherwise audio keeps flowing
    /// into a now-dead request and is silently dropped until the next scheduled
    /// rotation, which is exactly what causes speech after a pause to go missing.
    private func segmentEnded(_ segmentID: UUID) {
        finalizeSegment(segmentID)
        guard isRunning, let box = requestBox, segmentID == currentSegmentID else { return }
        let newRequest = makeRequest()
        _ = box.swap(newRequest)
        startRecognitionTask(with: newRequest)
    }

    private func finalizeSegment(_ segmentID: UUID) {
        guard let text = segmentTranscripts.removeValue(forKey: segmentID) else { return }
        appendCommitted(text)
        onPartialTranscript?(committedTranscript)
        if segmentID == finishingSegmentID {
            resolveFinal()
        }
    }

    private func appendCommitted(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        committedTranscript = committedTranscript.isEmpty ? trimmed : committedTranscript + " " + trimmed
    }

    private func scheduleSegmentRotation() {
        segmentTimer?.invalidate()
        segmentTimer = Timer.scheduledTimer(withTimeInterval: Self.rotationCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkRotationOpportunity() }
        }
    }

    private func checkRotationOpportunity() {
        guard isRunning else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(segmentStartTime)

        if recentLevel < Self.silenceLevelThreshold {
            if quietSince == nil { quietSince = now }
        } else {
            quietSince = nil
        }
        let quietDuration = quietSince.map { now.timeIntervalSince($0) } ?? 0

        let hitMax = elapsed >= Self.maxSegmentDuration
        let hitSilence = elapsed >= Self.minSegmentDurationBeforeSilenceRotate
            && quietDuration >= Self.silenceRotateDelay

        if hitMax || hitSilence {
            quietSince = nil
            rotateSegment()
        }
    }

    private func rotateSegment() {
        guard isRunning, let box = requestBox else { return }
        let newRequest = makeRequest()
        let oldRequest = box.swap(newRequest)
        // Start the new segment (updating currentSegmentID) before ending the old
        // request, so if its final callback lands synchronously-ish, segmentEnded's
        // `segmentID == currentSegmentID` check correctly sees it's stale and
        // doesn't try to start a second replacement segment.
        startRecognitionTask(with: newRequest)
        oldRequest.endAudio()
    }

    private func resolveFinal() {
        guard let continuation = finalContinuation else { return }
        finalContinuation = nil
        if let lastID = finishingSegmentID, let pending = segmentTranscripts.removeValue(forKey: lastID) {
            appendCommitted(pending)
        }
        continuation.resume(returning: committedTranscript)
    }
}
