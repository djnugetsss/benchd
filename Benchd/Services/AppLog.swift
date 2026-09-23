import Foundation
import os

/// Structured logging, so a data path that goes quiet can be traced without
/// adding and removing `print` statements.
///
/// Use the subsystem/category pairs below rather than making new ones inline —
/// they are what makes `log stream --predicate 'subsystem == "com.anshmehta.benchd"'`
/// useful on a real device.
enum AppLog {
    private static let subsystem = "com.anshmehta.benchd"

    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let profile = Logger(subsystem: subsystem, category: "profile")
    static let network = Logger(subsystem: subsystem, category: "network")
}
