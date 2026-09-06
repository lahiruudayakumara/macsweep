import Foundation
import OSLog

/// Docker cleanup requires Docker Engine commands so its internal database remains
/// consistent. Direct filesystem deletion is deliberately not offered as cleanup.
public struct DockerScanner: Sendable {
    public func scan(onProgress: (@Sendable (String) -> Void)? = nil, control: ScanControl? = nil) async -> [ScanItem] {
        guard await control?.waitUntilRunnable() ?? !Task.isCancelled else { return [] }
        Logger.scanner.info("Docker filesystem cleanup skipped; engine-managed pruning is required")
        return []
    }
}
