import Foundation
import OSLog

actor LocalLogService {
    private let logger = Logger(subsystem: "ai.tael.macagent", category: "invocation")

    func record(_ invocation: InvocationLog) {
        logger.info("\(invocation.summary, privacy: .public)")
    }
}
