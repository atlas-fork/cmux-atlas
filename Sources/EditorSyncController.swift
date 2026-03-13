import AppKit
import Combine
import Foundation

/// Automatically opens the selected workspace's directory in an external editor
/// (VS Code, Cursor, etc.) whenever the user switches workspaces in cmux.
///
/// When enabled, switching to a workspace triggers the configured editor to open
/// that workspace's `currentDirectory`. This gives a two-window workflow:
/// cmux on the left, editor on the right — clicking a workspace in cmux instantly
/// shows the matching project in the editor.
///
/// Behavior:
/// - Debounced: rapid workspace switching only triggers one editor open (300ms)
/// - Deduplicates: won't re-open the same directory if it's already the active one
/// - Configurable: target editor stored in UserDefaults
/// - Non-blocking: editor open is async and failures are silently ignored
@MainActor
final class EditorSyncController: ObservableObject {

    static let shared = EditorSyncController()

    // MARK: - Settings Keys

    static let enabledKey = "editorSync.enabled"
    static let targetEditorKey = "editorSync.targetEditor"

    // MARK: - Published State

    /// Whether editor sync is active.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        }
    }

    /// The editor to open on workspace switch.
    @Published var targetEditor: TerminalDirectoryOpenTarget {
        didSet {
            UserDefaults.standard.set(targetEditor.rawValue, forKey: Self.targetEditorKey)
        }
    }

    // MARK: - Internal State

    /// The last directory we opened in the editor, to avoid re-opening the same one.
    private var lastOpenedDirectory: String?

    /// Debounce timer for rapid workspace switching.
    private var debounceTask: Task<Void, Never>?

    /// Delay before triggering editor open (allows rapid tab switching to settle).
    private let debounceInterval: Duration = .milliseconds(300)

    // MARK: - Init

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)

        if let raw = UserDefaults.standard.string(forKey: Self.targetEditorKey),
           let target = TerminalDirectoryOpenTarget(rawValue: raw) {
            self.targetEditor = target
        } else {
            // Auto-detect: prefer Cursor, fall back to VS Code
            if TerminalDirectoryOpenTarget.cursor.applicationURL() != nil {
                self.targetEditor = .cursor
            } else if TerminalDirectoryOpenTarget.vscode.applicationURL() != nil {
                self.targetEditor = .vscode
            } else if TerminalDirectoryOpenTarget.zed.applicationURL() != nil {
                self.targetEditor = .zed
            } else if TerminalDirectoryOpenTarget.windsurf.applicationURL() != nil {
                self.targetEditor = .windsurf
            } else {
                self.targetEditor = .vscode
            }
        }
    }

    // MARK: - Workspace Switch Handler

    /// Called when the selected workspace changes. Opens the workspace's directory
    /// in the configured editor after a debounce delay.
    func workspaceDidChange(directory: String?) {
        guard isEnabled else { return }
        guard let directory, !directory.isEmpty else { return }

        // Cancel any pending debounce
        debounceTask?.cancel()

        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: self?.debounceInterval ?? .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.openDirectoryInEditor(directory)
        }
    }

    /// Opens a directory in the configured external editor.
    private func openDirectoryInEditor(_ directory: String) {
        // Don't re-open if it's the same directory
        guard directory != lastOpenedDirectory else { return }
        lastOpenedDirectory = directory

        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)

        // Use NSWorkspace to open the directory in the target editor
        guard let applicationURL = targetEditor.applicationURL() else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        // Don't activate the editor — keep cmux in focus
        configuration.activates = false

        NSWorkspace.shared.open(
            [directoryURL],
            withApplicationAt: applicationURL,
            configuration: configuration
        )
    }

    // MARK: - Available Editors

    /// Returns editors that are actually installed on this machine.
    static var availableEditors: [TerminalDirectoryOpenTarget] {
        let editorTargets: [TerminalDirectoryOpenTarget] = [
            .cursor, .vscode, .windsurf, .zed, .xcode, .androidStudio, .antigravity
        ]
        return editorTargets.filter { $0.applicationURL() != nil }
    }
}
