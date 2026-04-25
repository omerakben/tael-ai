import Foundation

enum PermissionKind: String, CaseIterable, Equatable, Sendable {
    case screenRecording
    case accessibility
    case microphone
    case appleEvents
    case inputMonitoring
    case clipboardWrite
    case subprocessAction
    case keyboardMouseAutomation

    var displayName: String {
        switch self {
        case .screenRecording:
            return "Screen Recording"
        case .accessibility:
            return "Accessibility"
        case .microphone:
            return "Microphone"
        case .appleEvents:
            return "Apple Events"
        case .inputMonitoring:
            return "Input Monitoring"
        case .clipboardWrite:
            return "Clipboard Write"
        case .subprocessAction:
            return "Subprocess Action"
        case .keyboardMouseAutomation:
            return "Keyboard and Mouse Automation"
        }
    }
}
