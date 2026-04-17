import Foundation
import AppKit

final class UpdateLogStore {
    static let shared = UpdateLogStore()

    private let queue = DispatchQueue(label: "cmux.update.log")
    private var entries: [String] = []
    private let maxEntries = 200
    private let logURL: URL
    private let formatter: ISO8601DateFormatter

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        logURL = logsDir.appendingPathComponent("Logs/cmux-update.log")
        ensureLogFile()
    }

    func append(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let bundle = Bundle.main.bundleIdentifier ?? "<no.bundle.id>"
        let pid = ProcessInfo.processInfo.processIdentifier
        let line = "[\(timestamp)] [\(bundle):\(pid)] \(message)"
        queue.async { [weak self] in
            guard let self else { return }
            entries.append(line)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            appendToFile(line: line)
        }
    }

    func snapshot() -> String {
        queue.sync {
            entries.joined(separator: "\n")
        }
    }

    func logPath() -> String {
        logURL.path
    }

    private func ensureLogFile() {
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try? Data().write(to: logURL)
        }
    }

    private func appendToFile(line: String) {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}

final class FocusLogStore {
    static let shared = FocusLogStore()

    private let queue = DispatchQueue(label: "cmux.focus.log")
    private var entries: [String] = []
    private let maxEntries = 400
    private let logURL: URL
    private let formatter: ISO8601DateFormatter

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        logURL = logsDir.appendingPathComponent("Logs/cmux-focus.log")
        ensureLogFile()
    }

    func append(_ message: String) {
        #if DEBUG
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        queue.async { [weak self] in
            guard let self else { return }
            entries.append(line)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            appendToFile(line: line)
        }
        #endif
    }

    func snapshot() -> String {
        queue.sync {
            entries.joined(separator: "\n")
        }
    }

    func logPath() -> String {
        logURL.path
    }

    private func ensureLogFile() {
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try? Data().write(to: logURL)
        }
    }

    private func appendToFile(line: String) {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}

final class LifecycleLogStore {
    static let shared = LifecycleLogStore()

    private let queue = DispatchQueue(label: "cmux.lifecycle.log")
    private var entries: [String] = []
    private let maxEntries = 400
    private let logURL: URL
    private let stateURL: URL
    private let formatter: ISO8601DateFormatter
    private var pendingAISessionRefreshAbnormalExitContext: [String: Any]?

    private struct LifecycleRunState: Codable {
        var activePid: Int?
        var activeLaunchAt: TimeInterval?
        var shortVersion: String?
        var buildVersion: String?
        var terminationRequestedAt: TimeInterval?
        var terminatedAt: TimeInterval?
        var expectedRelaunchAt: TimeInterval?
        var aiSessionRefreshActiveAt: TimeInterval?
        var aiSessionRefreshActiveCount: Int?
    }

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        logURL = logsDir.appendingPathComponent("Logs/cmux-lifecycle.log")
        stateURL = logsDir.appendingPathComponent("Logs/cmux-lifecycle-state.json")
        ensureLogFile()
        ensureStateFile()
    }

    func append(_ message: String) {
        queue.async { [weak self] in
            guard let self else { return }
            appendUnlocked(makeLine(message))
        }
    }

    func snapshot() -> String {
        queue.sync {
            entries.joined(separator: "\n")
        }
    }

    func recordLaunch(
        shortVersion: String,
        buildVersion: String,
        telemetryEnabled: Bool,
        isRunningUnderXCTest: Bool
    ) {
        queue.sync {
            let now = Date().timeIntervalSince1970
            let currentPid = Int(ProcessInfo.processInfo.processIdentifier)
            var state = loadStateUnlocked()
            if let previousPid = state.activePid,
               let previousLaunchAt = state.activeLaunchAt,
               previousPid != currentPid {
                let terminatedAt = state.terminatedAt ?? 0
                let didTerminateCleanly = terminatedAt >= previousLaunchAt
                let expectedRelaunchAt = state.expectedRelaunchAt ?? 0
                let expectedRelaunch = expectedRelaunchAt >= previousLaunchAt
                let aiRefreshWasActive = (state.aiSessionRefreshActiveCount ?? 0) > 0
                    && (state.aiSessionRefreshActiveAt ?? 0) >= previousLaunchAt
                if !didTerminateCleanly {
                    let launchText = formatter.string(from: Date(timeIntervalSince1970: previousLaunchAt))
                    let event = expectedRelaunch ? "previousRunMissingWillTerminateAfterExpectedRelaunch" : "previousRunAbnormalExitDetected"
                    appendUnlocked(makeLine("\(event) previousPid=\(previousPid) previousLaunchAt=\(launchText)"))
                    if aiRefreshWasActive {
                        appendUnlocked(
                            makeLine(
                                "previousRunAbnormalExitDuringAISessionRefresh previousPid=\(previousPid) previousLaunchAt=\(launchText)"
                            )
                        )
                        pendingAISessionRefreshAbnormalExitContext = [
                            "previousPid": previousPid,
                            "previousLaunchAt": launchText,
                            "expectedRelaunch": expectedRelaunch
                        ]
                    }
                }
            }

            state.activePid = currentPid
            state.activeLaunchAt = now
            state.shortVersion = shortVersion
            state.buildVersion = buildVersion
            state.terminationRequestedAt = nil
            state.terminatedAt = nil
            state.expectedRelaunchAt = nil
            state.aiSessionRefreshActiveAt = nil
            state.aiSessionRefreshActiveCount = 0
            saveStateUnlocked(state)

            appendUnlocked(
                makeLine(
                    "applicationDidFinishLaunching version=\(shortVersion) build=\(buildVersion) " +
                        "telemetry=\(telemetryEnabled ? 1 : 0) xctest=\(isRunningUnderXCTest ? 1 : 0)"
                )
            )
        }
    }

    func recordTerminationRequested() {
        queue.sync {
            var state = loadStateUnlocked()
            state.terminationRequestedAt = Date().timeIntervalSince1970
            saveStateUnlocked(state)
            appendUnlocked(makeLine("applicationShouldTerminate"))
        }
    }

    func recordWillTerminate() {
        queue.sync {
            var state = loadStateUnlocked()
            state.terminatedAt = Date().timeIntervalSince1970
            state.aiSessionRefreshActiveAt = nil
            state.aiSessionRefreshActiveCount = 0
            saveStateUnlocked(state)
            appendUnlocked(makeLine("applicationWillTerminate"))
        }
    }

    func recordExpectedRelaunch() {
        queue.sync {
            var state = loadStateUnlocked()
            state.expectedRelaunchAt = Date().timeIntervalSince1970
            saveStateUnlocked(state)
            appendUnlocked(makeLine("persistSessionForUpdateRelaunch"))
        }
    }

    func recordDuplicateTerminationRequest(for app: NSRunningApplication) {
        append("duplicateTermination.request pid=\(app.processIdentifier) bundle=\(app.bundleIdentifier ?? "<nil>")")
    }

    func recordDuplicateTerminationForce(for app: NSRunningApplication) {
        append("duplicateTermination.force pid=\(app.processIdentifier) bundle=\(app.bundleIdentifier ?? "<nil>")")
    }

    func recordAISessionRefreshStarted() {
        queue.sync {
            var state = loadStateUnlocked()
            let nextCount = max(0, state.aiSessionRefreshActiveCount ?? 0) + 1
            state.aiSessionRefreshActiveCount = nextCount
            if nextCount == 1 {
                state.aiSessionRefreshActiveAt = Date().timeIntervalSince1970
            }
            saveStateUnlocked(state)
        }
    }

    func recordAISessionRefreshFinished() {
        queue.sync {
            var state = loadStateUnlocked()
            let currentCount = max(0, state.aiSessionRefreshActiveCount ?? 0)
            let nextCount = max(0, currentCount - 1)
            state.aiSessionRefreshActiveCount = nextCount
            if nextCount == 0 {
                state.aiSessionRefreshActiveAt = nil
            }
            saveStateUnlocked(state)
        }
    }

    func consumePendingAISessionRefreshAbnormalExitContext() -> [String: Any]? {
        queue.sync {
            defer { pendingAISessionRefreshAbnormalExitContext = nil }
            return pendingAISessionRefreshAbnormalExitContext
        }
    }

    func logPath() -> String {
        logURL.path
    }

    func statePath() -> String {
        stateURL.path
    }

    private func ensureLogFile() {
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try? Data().write(to: logURL)
        }
    }

    private func ensureStateFile() {
        let directory = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: stateURL.path) {
            try? Data("{}".utf8).write(to: stateURL)
        }
    }

    private func makeLine(_ message: String) -> String {
        let timestamp = formatter.string(from: Date())
        let bundle = Bundle.main.bundleIdentifier ?? "<no.bundle.id>"
        let pid = ProcessInfo.processInfo.processIdentifier
        return "[\(timestamp)] [\(bundle):\(pid)] \(message)"
    }

    private func appendUnlocked(_ line: String) {
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        appendToFile(line: line)
    }

    private func loadStateUnlocked() -> LifecycleRunState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(LifecycleRunState.self, from: data) else {
            return LifecycleRunState()
        }
        return state
    }

    private func saveStateUnlocked(_ state: LifecycleRunState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    private func appendToFile(line: String) {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}
