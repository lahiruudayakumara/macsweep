import Foundation
import SwiftUI
import Combine

@MainActor
public final class StorageManagerViewModel: ObservableObject {

    // MARK: - State

    public enum ViewState { case idle, loading, results, error(String) }

    @Published public var viewState: ViewState = .idle
    @Published public var volumes: [ExternalVolume] = []
    @Published public var selectedVolumeID: UUID?

    // Per-volume top-level directory listing
    @Published public var volumeContents: [UUID: [VolumeDirectory]] = [:]
    @Published public var loadingVolumeID: UUID?

    private let volumeService: VolumeService

    public init(environment: AppEnvironment) {
        self.volumeService = environment.volumeService
    }

    public var selectedVolume: ExternalVolume? {
        volumes.first { $0.id == selectedVolumeID }
    }

    public var selectedVolumeContents: [VolumeDirectory] {
        guard let id = selectedVolumeID else { return [] }
        return volumeContents[id] ?? []
    }

    // MARK: - Load

    public func load() async {
        viewState = .loading
        volumes = await volumeService.discoverVolumes()
        if selectedVolumeID == nil {
            selectedVolumeID = volumes.first?.id
        }
        if let id = selectedVolumeID {
            await loadContents(for: id)
        }
        viewState = .results
    }

    public func selectVolume(_ volume: ExternalVolume) async {
        if selectedVolumeID != volume.id {
            selectedVolumeID = volume.id
        }
        if volumeContents[volume.id] == nil {
            await loadContents(for: volume.id)
        }
    }

    private func loadContents(for id: UUID) async {
        guard let volume = volumes.first(where: { $0.id == id }) else { return }
        loadingVolumeID = id
        let dirs = await VolumeDirectory.scan(volume: volume)
        volumeContents[id] = dirs
        loadingVolumeID = nil
    }

    public func refresh() async {
        volumeContents.removeAll()
        await load()
    }
}

// MARK: - VolumeDirectory

/// A top-level directory entry within a volume with pre-calculated size.
public struct VolumeDirectory: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let url: URL
    public let name: String
    public let size: Int64
    public let isDirectory: Bool
    public let itemCount: Int

    public var formattedSize: String { ByteFormatter.format(size) }

    public static func scan(volume: ExternalVolume) async -> [VolumeDirectory] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: volume.url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [VolumeDirectory] = []
        for url in contents {
            let res = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey])
            let isDir = res?.isDirectory ?? false
            let size: Int64
            var itemCount = 0
            if isDir {
                size = await FileEnumerator.directorySize(url)
                itemCount = (try? fm.contentsOfDirectory(atPath: url.path).count) ?? 0
            } else {
                size = Int64(res?.totalFileAllocatedSize ?? res?.fileSize ?? 0)
            }
            result.append(VolumeDirectory(url: url, name: url.lastPathComponent, size: size, isDirectory: isDir, itemCount: itemCount))
        }
        return result.sorted { $0.size > $1.size }
    }

    private init(url: URL, name: String, size: Int64, isDirectory: Bool, itemCount: Int) {
        self.url = url
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.itemCount = itemCount
    }
}
