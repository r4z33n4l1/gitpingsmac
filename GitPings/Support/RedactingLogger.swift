import Foundation
import OSLog

/// Logs must never include tokens, authorization headers, refresh tokens, device codes, cookies, or private payloads.
public struct RedactingLogger: Sendable {
    private let logger: Logger

    public init(subsystem: String = "com.razeenali.gitpings", category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func info(_ message: String) {
        logger.info("\(Self.redact(message), privacy: .public)")
    }

    public func error(_ message: String) {
        logger.error("\(Self.redact(message), privacy: .public)")
    }

    public static func redact(_ message: String) -> String {
        var output = message
        let patterns: [(String, String)] = [
            (#"(?i)(authorization\s*[:=]\s*)(?:bearer\s+)?(\S+)"#, "$1[REDACTED]"),
            (#"(?i)(bearer\s+)([A-Za-z0-9\-._~+/]+=*)"#, "$1[REDACTED]"),
            (#"(?i)(access[_-]?token\s*[:=]\s*)(\S+)"#, "$1[REDACTED]"),
            (#"(?i)(refresh[_-]?token\s*[:=]\s*)(\S+)"#, "$1[REDACTED]"),
            (#"(?i)(device[_-]?code\s*[:=]\s*)(\S+)"#, "$1[REDACTED]"),
            (#"(?i)(user[_-]?code\s*[:=]\s*)(\S+)"#, "$1[REDACTED]"),
            (#"(?i)(client[_-]?secret\s*[:=]\s*)(\S+)"#, "$1[REDACTED]"),
        ]

        for (pattern, template) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(output.startIndex..<output.endIndex, in: output)
                output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: template)
            }
        }
        return output
    }
}
