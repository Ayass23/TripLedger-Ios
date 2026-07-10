import Foundation

// MARK: - App Log
/// Debug-only logger. Behaves exactly like `print` in DEBUG builds and
/// compiles to a no-op in Release, so diagnostic logs never ship to users.
enum AppLog {
    static func debug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        #if DEBUG
        print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
        #endif
    }
}
