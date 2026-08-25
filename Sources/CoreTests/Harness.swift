import Foundation

/// A test harness small enough to have no dependencies.
///
/// XCTest and swift-testing both ship with Xcode rather than the
/// Command Line Tools, so a package that relies on either can only be
/// tested on a machine set up for app development. This one runs
/// wherever `swift` does.
final class Harness {

    private var checks = 0
    private var failures: [String] = []
    private var currentTest = "(none)"
    private var currentSuite = ""

    func suite(_ name: String, _ body: (Harness) -> Void) {
        currentSuite = name
        print("\n\(name)")
        body(self)
    }

    func test(_ name: String, _ body: () throws -> Void) {
        currentTest = name
        let before = failures.count

        do {
            try body()
        } catch {
            record("threw an unexpected error: \(error)", file: #fileID, line: #line)
        }

        let mark = failures.count == before ? "  ok  " : "  FAIL"
        print("\(mark)  \(name)")
    }

    func expect(
        _ condition: Bool, _ what: String,
        file: StaticString = #fileID, line: UInt = #line
    ) {
        checks += 1
        if !condition { record(what, file: file, line: line) }
    }

    func equal<T: Equatable>(
        _ actual: T, _ expected: T, _ what: String,
        file: StaticString = #fileID, line: UInt = #line
    ) {
        checks += 1
        if actual != expected {
            record("\(what): expected \(expected), got \(actual)",
                   file: file, line: line)
        }
    }

    func isNil<T>(
        _ actual: T?, _ what: String,
        file: StaticString = #fileID, line: UInt = #line
    ) {
        checks += 1
        if let actual {
            record("\(what): expected nil, got \(actual)", file: file, line: line)
        }
    }

    func throwsError<E: Error & Equatable, T>(
        _ expected: E, _ what: String,
        file: StaticString = #fileID, line: UInt = #line,
        _ body: () throws -> T
    ) {
        checks += 1
        do {
            let value = try body()
            record("\(what): expected \(expected), but it returned \(value)",
                   file: file, line: line)
        } catch let error as E where error == expected {
            return
        } catch {
            record("\(what): expected \(expected), got \(error)",
                   file: file, line: line)
        }
    }

    private func record(_ message: String, file: StaticString, line: UInt) {
        failures.append("\(currentSuite) / \(currentTest)\n"
                        + "      \(message)\n"
                        + "      at \(file):\(line)")
    }

    /// Prints the tally and returns the process exit code.
    func report() -> Int32 {
        print("")

        guard failures.isEmpty else {
            print("\(failures.count) of \(checks) checks failed\n")
            for failure in failures { print("  - \(failure)") }
            return 1
        }

        print("\(checks) checks passed")
        return 0
    }
}
