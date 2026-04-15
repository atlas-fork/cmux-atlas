import Foundation
import Darwin

/// Lightweight process resource query helpers.
///
/// The SQLite-backed sample/incident/metrickit database that previously lived
/// here has been removed — it caused runaway disk writes (VACUUM on a 500 MB
/// database) that made macOS terminate the app via EXC_RESOURCE.
///
/// Memory pressure monitoring and the Ctrl-C safeguard remain in TabManager;
/// they never depended on the database.
final class MemoryDiagnosticsStore {
    static let shared = MemoryDiagnosticsStore()

    private init() {}

    // MARK: - Process resource usage queries

    private struct ProcessResourceUsageSnapshot {
        let userTimeNs: UInt64
        let systemTimeNs: UInt64
        let cpuTimeNs: UInt64
        let footprintBytes: Int64
        let lifetimeMaxFootprintBytes: Int64?
    }

    private static func queryResourceUsage(for pid: Int32) -> ProcessResourceUsageSnapshot? {
        guard pid > 0 else { return nil }

        var info = proc_taskinfo()
        let expectedSize = Int32(MemoryLayout<proc_taskinfo>.stride)
        let status = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, expectedSize)
        guard status == expectedSize else { return nil }

        let userTimeNs = info.pti_total_user
        let systemTimeNs = info.pti_total_system
        return ProcessResourceUsageSnapshot(
            userTimeNs: userTimeNs,
            systemTimeNs: systemTimeNs,
            cpuTimeNs: userTimeNs + systemTimeNs,
            footprintBytes: Int64(info.pti_resident_size),
            lifetimeMaxFootprintBytes: nil
        )
    }

#if DEBUG
    static func debugResourceUsageSnapshotForTesting(pid: Int32) -> (cpuTimeNs: UInt64, footprintBytes: Int64)? {
        guard let snapshot = queryResourceUsage(for: pid) else { return nil }
        return (
            cpuTimeNs: snapshot.cpuTimeNs,
            footprintBytes: snapshot.footprintBytes
        )
    }
#endif

    // MARK: - Stubs for removed database operations

    /// No-op — database recording has been removed.
    func recordSample(
        snapshot: MemoryUsageSnapshot,
        rows: [ProcessTreeRow],
        trackedOwners: [TrackedProcessOwner]
    ) {}

    /// No-op — database recording has been removed.
    func captureIncident(
        reason: String,
        pressureLevel: SystemMemoryPressureLevel,
        source: String
    ) {}

    /// Returns an empty JSON object — database queries have been removed.
    func recentSamplesJSON(limit: Int) -> String { "{\"samples\":[]}" }

    /// Returns an empty JSON object — database queries have been removed.
    func recentIncidentsJSON(limit: Int) -> String { "{\"incidents\":[]}" }

    /// Returns an empty JSON object — database queries have been removed.
    func recentMetricPayloadsJSON(limit: Int) -> String { "{\"payloads\":[]}" }

    /// Returns a message explaining the feature was removed.
    func createManualDump(reason: String) -> String {
        "{\"ok\":false,\"message\":\"Memory diagnostics database has been removed. Use an external monitoring tool.\"}"
    }
}
