import Foundation
import OSLog

/// Discovers mounted disk volumes (internal and external) and provides space information.
public final class VolumeService: Sendable {
    private let fileManager = FileManager.default

    public init() {}

    /// Returns all currently mounted readable volumes.
    public func discoverVolumes() async -> [ExternalVolume] {
        var result: [ExternalVolume] = []
        let resourceKeys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey,
            .volumeUUIDStringKey
        ]

        guard let mountedURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(resourceKeys),
            options: [.skipHiddenVolumes]
        ) else {
            Logger.storage.error("Failed to enumerate mounted volumes")
            return result
        }

        for url in mountedURLs {
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
            guard let totalCapacity = values.volumeTotalCapacity else { continue }
            let available = values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)
            let isInternal = values.volumeIsInternal ?? true
            let isRemovable = values.volumeIsRemovable ?? false
            let isEjectable = values.volumeIsEjectable ?? false
            let isReadOnly = values.volumeIsReadOnly ?? false
            let name = values.volumeName ?? url.lastPathComponent
            let uuid = values.volumeUUIDString ?? ""

            // Skip very small pseudo volumes (< 100 MB)
            if totalCapacity < 100_000_000 { continue }

            result.append(ExternalVolume(
                name: name,
                url: url,
                totalCapacity: Int64(totalCapacity),
                availableCapacity: available,
                isRemovable: isRemovable || isEjectable,
                isExternal: !isInternal,
                isReadOnly: isReadOnly,
                volumeUUID: uuid
            ))
        }

        // Internal volumes first, then external alphabetically
        result.sort {
            if $0.isExternal != $1.isExternal { return !$0.isExternal }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        Logger.storage.info("Discovered \(result.count) volumes")
        return result
    }

    /// Refreshes capacity info for a single volume URL.
    public func refreshVolume(_ url: URL) -> ExternalVolume? {
        let resourceKeys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey,
            .volumeUUIDStringKey
        ]
        guard let values = try? url.resourceValues(forKeys: resourceKeys),
              let totalCapacity = values.volumeTotalCapacity else { return nil }
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        return ExternalVolume(
            name: values.volumeName ?? url.lastPathComponent,
            url: url,
            totalCapacity: Int64(totalCapacity),
            availableCapacity: available,
            isRemovable: (values.volumeIsRemovable ?? false) || (values.volumeIsEjectable ?? false),
            isExternal: !(values.volumeIsInternal ?? true),
            isReadOnly: values.volumeIsReadOnly ?? false,
            volumeUUID: values.volumeUUIDString ?? ""
        )
    }
}
