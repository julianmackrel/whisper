import AppKit
import ApplicationServices
import AVFoundation
import Speech

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

@MainActor
final class PermissionsCoordinator {

    func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    /// Triggers the system Accessibility prompt if not already granted. Safe to call repeatedly.
    func requestAccessibilityPrompt() {
        let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func microphoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func speechStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestSpeechAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Requests mic + speech (system dialogs) and prompts for Accessibility (System Settings toggle).
    /// Call once at launch.
    func bootstrapAll() async {
        if microphoneStatus() == .notDetermined {
            _ = await requestMicrophoneAccess()
        }
        if speechStatus() == .notDetermined {
            _ = await requestSpeechAccess()
        }
        if accessibilityStatus() != .granted {
            requestAccessibilityPrompt()
        }
    }

    var allGranted: Bool {
        accessibilityStatus() == .granted
            && microphoneStatus() == .granted
            && speechStatus() == .granted
    }
}
