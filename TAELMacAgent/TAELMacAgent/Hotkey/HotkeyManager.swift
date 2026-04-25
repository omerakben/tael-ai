import Foundation

@MainActor
final class HotkeyManager {
    private let onInvoke: () -> Void
    private(set) var isRunning = false

    init(onInvoke: @escaping () -> Void) {
        self.onInvoke = onInvoke
    }

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func simulateInvocationForDebug() {
        guard isRunning else {
            return
        }

        onInvoke()
    }
}
