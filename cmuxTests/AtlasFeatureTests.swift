import XCTest
import Foundation

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// Regression tests for atlas-fork-specific features.
@MainActor
final class AtlasFeatureTests: XCTestCase {

    private let autosaveKey = "NSWindow Frame cmux.ContentView-AppWindow-main"

    override func tearDown() {
        _ = MainWindowAutosaveFrameSanitizer.takePendingTelemetryRecords()
        super.tearDown()
    }

    // MARK: - Finder Reveal Extensions

    func testFinderRevealExtensionsContainsArchives() {
        for ext in ["zip", "dmg", "tar", "pkg", "gz", "7z", "rar", "iso"] {
            XCTAssertTrue(
                terminalRevealInFinderExtensions.contains(ext),
                "terminalRevealInFinderExtensions missing archive extension: \(ext)"
            )
        }
    }

    func testFinderRevealExtensionsContainsMedia() {
        for ext in ["png", "jpg", "jpeg", "mp4", "mov", "mp3", "heic"] {
            XCTAssertTrue(
                terminalRevealInFinderExtensions.contains(ext),
                "terminalRevealInFinderExtensions missing media extension: \(ext)"
            )
        }
    }

    // MARK: - Link Resolution

    func testResolvesZipAsLocalFile() throws {
        let target = try XCTUnwrap(resolveTerminalOpenURLTarget("/tmp/test.zip"))
        switch target {
        case .localFile(let reference):
            XCTAssertEqual(reference.path, "/tmp/test.zip")
        default:
            XCTFail("Expected .zip path to resolve as .localFile, got \(target)")
        }
    }

    func testResolvesHtmlAsLocalFile() throws {
        let target = try XCTUnwrap(resolveTerminalOpenURLTarget("./report.html"))
        switch target {
        case .localFile(let reference):
            XCTAssertEqual(reference.path, "./report.html")
        default:
            XCTFail("Expected .html relative path to resolve as .localFile, got \(target)")
        }
    }

    func testArchiveFilesRevealInFinderEvenWhenCmuxBrowserEnabled() {
        XCTAssertEqual(
            terminalLocalFileOpenDisposition(
                path: "/tmp/archive.zip",
                openInCmuxBrowser: true
            ),
            .revealInFinder
        )
    }

    func testRenderableLocalFilesOpenExternallyWhenCmuxBrowserDisabled() {
        XCTAssertEqual(
            terminalLocalFileOpenDisposition(
                path: "/tmp/report.html",
                openInCmuxBrowser: false
            ),
            .openExternally
        )
    }

    func testRenderableLocalFilesOpenInCmuxBrowserWhenEnabled() {
        XCTAssertEqual(
            terminalLocalFileOpenDisposition(
                path: "/tmp/report.html",
                openInCmuxBrowser: true
            ),
            .openInCmuxBrowser
        )
    }

    // MARK: - Startup Sanitizer

    func testAutosaveSanitizerRemovesOversizedMainWindowFrame() {
        let suiteName = "AtlasFeatureTests.Autosave.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("0 0 12050 900 0 0 1440 900", forKey: autosaveKey)

        MainWindowAutosaveFrameSanitizer.sanitizeIfNeeded(
            defaults: defaults,
            screenVisibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        )

        XCTAssertNil(defaults.object(forKey: autosaveKey))
        XCTAssertEqual(
            MainWindowAutosaveFrameSanitizer.takePendingTelemetryRecords(),
            [
                .init(
                    key: autosaveKey,
                    encodedValue: "0 0 12050 900 0 0 1440 900",
                    parsedFrame: CGRect(x: 0, y: 0, width: 12050, height: 900),
                    parsedScreenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
                )
            ]
        )
    }

    func testAutosaveSanitizerPreservesReasonableMainWindowFrame() {
        let suiteName = "AtlasFeatureTests.Autosave.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let encodedFrame = "10 20 1280 820 0 0 1440 900"
        defaults.set(encodedFrame, forKey: autosaveKey)

        MainWindowAutosaveFrameSanitizer.sanitizeIfNeeded(
            defaults: defaults,
            screenVisibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        )

        XCTAssertEqual(defaults.string(forKey: autosaveKey), encodedFrame)
        XCTAssertTrue(MainWindowAutosaveFrameSanitizer.takePendingTelemetryRecords().isEmpty)
    }

    // MARK: - Quick Launch

    func testClaudeQuickLaunchUsesFocusedPanelDirectoryAndQueuesCommand() throws {
        let quickLaunch = AIQuickLaunchController.shared
        let savedCodexPermissiveMode = quickLaunch.codexPermissiveMode
        let savedClaudePermissiveMode = quickLaunch.claudePermissiveMode
        defer {
            quickLaunch.codexPermissiveMode = savedCodexPermissiveMode
            quickLaunch.claudePermissiveMode = savedClaudePermissiveMode
        }

        quickLaunch.claudePermissiveMode = false
        let workspace = Workspace()
        let sourcePanelId = try XCTUnwrap(workspace.focusedPanelId)
        let expectedDirectory = "/tmp/atlas-claude-\(UUID().uuidString)"
        workspace.panelDirectories[sourcePanelId] = expectedDirectory
        let panelCountBefore = workspace.panels.count

        workspace.launchQuickAIAgent(.claudeCode)

        XCTAssertEqual(workspace.panels.count, panelCountBefore + 1)
        let launchedPanelId = try XCTUnwrap(workspace.focusedPanelId)
        XCTAssertNotEqual(launchedPanelId, sourcePanelId)

        let launchedPanel = try XCTUnwrap(workspace.terminalPanel(for: launchedPanelId))
        XCTAssertEqual(launchedPanel.requestedWorkingDirectory, expectedDirectory)
        XCTAssertEqual(launchedPanel.queuedTextForTesting(), "claude\r")
    }

    func testCodexQuickLaunchFallsBackToWorkspaceDirectoryAndRespectsPermissiveMode() throws {
        let quickLaunch = AIQuickLaunchController.shared
        let savedCodexPermissiveMode = quickLaunch.codexPermissiveMode
        let savedClaudePermissiveMode = quickLaunch.claudePermissiveMode
        defer {
            quickLaunch.codexPermissiveMode = savedCodexPermissiveMode
            quickLaunch.claudePermissiveMode = savedClaudePermissiveMode
        }

        quickLaunch.codexPermissiveMode = true
        let workspace = Workspace()
        let sourcePanelId = try XCTUnwrap(workspace.focusedPanelId)
        workspace.panelDirectories.removeValue(forKey: sourcePanelId)
        workspace.currentDirectory = "/tmp/atlas-codex-\(UUID().uuidString)"

        workspace.launchQuickAIAgent(.codex)

        let launchedPanelId = try XCTUnwrap(workspace.focusedPanelId)
        let launchedPanel = try XCTUnwrap(workspace.terminalPanel(for: launchedPanelId))
        XCTAssertEqual(launchedPanel.requestedWorkingDirectory, workspace.currentDirectory)
        XCTAssertEqual(launchedPanel.queuedTextForTesting(), "codex --yolo\r")
    }

    func testQuickLaunchMenuCommandsExposeExpectedShortcutsAndTitles() {
        let commands = AIQuickLaunchMenuCommandSpec.all
        XCTAssertEqual(commands.count, 2)

        let claudeCommand = AIQuickLaunchMenuCommandSpec.command(for: .claudeCode)
        XCTAssertEqual(claudeCommand.title, "New Claude Code")
        XCTAssertEqual(claudeCommand.keyCharacter, "a")
        XCTAssertTrue(claudeCommand.eventModifiers.contains(.command))
        XCTAssertTrue(claudeCommand.eventModifiers.contains(.option))

        let codexCommand = AIQuickLaunchMenuCommandSpec.command(for: .codex)
        XCTAssertEqual(codexCommand.title, "New Codex")
        XCTAssertEqual(codexCommand.keyCharacter, "x")
        XCTAssertTrue(codexCommand.eventModifiers.contains(.command))
        XCTAssertTrue(codexCommand.eventModifiers.contains(.option))
    }

    func testQuickLaunchMenuCommandsStayUniquelyMappedToAgentsAndShortcuts() {
        let commands = AIQuickLaunchMenuCommandSpec.all

        XCTAssertEqual(
            Set(commands.map(\.title)).count,
            commands.count,
            "Expected each quick-launch menu command title to be unique"
        )
        XCTAssertEqual(
            Set(commands.map { "\($0.keyCharacter)-\($0.eventModifiers.rawValue)" }).count,
            commands.count,
            "Expected each quick-launch menu shortcut to map to exactly one agent"
        )
    }

    // MARK: - Memory Diagnostics

    func testMemoryDiagnosticsCommandsReturnStubbedEmptyPayloads() {
        XCTAssertEqual(
            MemoryDiagnosticsStore.shared.recentSamplesJSON(limit: 0),
            #"{"samples":[]}"#
        )
        XCTAssertEqual(
            MemoryDiagnosticsStore.shared.recentIncidentsJSON(limit: 0),
            #"{"incidents":[]}"#
        )
        XCTAssertEqual(
            MemoryDiagnosticsStore.shared.recentMetricPayloadsJSON(limit: 0),
            #"{"payloads":[]}"#
        )
    }

    func testMemoryDumpCommandReturnsRemovedMessage() {
        XCTAssertEqual(
            MemoryDiagnosticsStore.shared.createManualDump(reason: "atlas manual"),
            #"{"ok":false,"message":"Memory diagnostics database has been removed. Use an external monitoring tool."}"#
        )
    }

    func testMemoryDiagnosticsResourceUsageQuerySurvivesRepeatedCurrentProcessCalls() throws {
        let pid = getpid()
        var sawSnapshot = false

        for _ in 0..<256 {
            guard let snapshot = MemoryDiagnosticsStore.debugResourceUsageSnapshotForTesting(pid: pid) else {
                XCTFail("Expected resource usage snapshot for current process")
                return
            }
            XCTAssertGreaterThanOrEqual(snapshot.cpuTimeNs, 0)
            XCTAssertGreaterThanOrEqual(snapshot.footprintBytes, 0)
            sawSnapshot = true
        }

        XCTAssertTrue(sawSnapshot)
    }

    // MARK: - AI Session Detection

    func testAISessionDetectorFindsRecentEntryInLargeJSONLFile() throws {
        AISessionDetector.debugResetEntryScanCache()

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("atlas-ai-session-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let oldLine = #"{"timestamp":"2026-04-17T00:00:00.000Z","type":"message"}"#
        let newLine = #"{"timestamp":"2026-04-17T09:30:05.000Z","type":"message"}"#
        let filler = String(repeating: oldLine + "\n", count: 12_000)
        try (filler + newLine + "\n").write(to: fileURL, atomically: true, encoding: .utf8)

        let epoch = try XCTUnwrap(AISessionDetector.parseISO8601Epoch("2026-04-17T09:30:00.000Z"))
        let match = try XCTUnwrap(
            AISessionDetector.debugFindFirstEntryAfter(epoch: epoch, inFile: fileURL.path)
        )

        XCTAssertEqual(match.epoch, epoch + 5)
        XCTAssertEqual(match.delta, 5)
    }

    func testAISessionDetectorFindsRecentEntryInSmallJSONLFile() throws {
        AISessionDetector.debugResetEntryScanCache()

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("atlas-ai-small-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let content = [
            #"{"timestamp":"2026-04-17T09:29:50.000Z","type":"message"}"#,
            #"{"timestamp":"2026-04-17T09:30:01.000Z","type":"message"}"#,
        ].joined(separator: "\n") + "\n"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let epoch = try XCTUnwrap(AISessionDetector.parseISO8601Epoch("2026-04-17T09:30:00.000Z"))
        let match = try XCTUnwrap(
            AISessionDetector.debugFindFirstEntryAfter(epoch: epoch, inFile: fileURL.path)
        )

        XCTAssertEqual(match.line, 1)
        XCTAssertEqual(match.epoch, epoch + 1)
        XCTAssertEqual(match.delta, 1)
    }

    // MARK: - Settings Defaults

    func testAutoResumeOnExitDefaultsToTrue() {
        let defaults = UserDefaults(suiteName: "AtlasFeatureTests-\(UUID().uuidString)")!
        // Empty defaults should return true (the default value)
        XCTAssertTrue(ClaudeCodeIntegrationSettings.autoResumeOnExit(defaults: defaults))
        // Explicitly set to false
        defaults.set(false, forKey: ClaudeCodeIntegrationSettings.autoResumeOnExitKey)
        XCTAssertFalse(ClaudeCodeIntegrationSettings.autoResumeOnExit(defaults: defaults))
    }
}
