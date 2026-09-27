import Foundation
import SwiftUI

/// An associated support folder or cache file for an application (e.g. Application Support, Containers, Caches).
public struct AppAssociatedItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let sourcePath: URL
    public let category: String // "Application Support", "Containers", "Caches", "Preferences", "Saved State", "HTTP Storage"
    public let size: Int64
    public var isSymlink: Bool
    public var symlinkDestination: URL?

    public var formattedSize: String { ByteFormatter.format(size) }

    public init(
        id: UUID = UUID(),
        name: String,
        sourcePath: URL,
        category: String,
        size: Int64,
        isSymlink: Bool = false,
        symlinkDestination: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.category = category
        self.size = size
        self.isSymlink = isSymlink
        self.symlinkDestination = symlinkDestination
    }
}

/// A movable application (full app bundle + associated data) or large developer/tool data folder.
public struct ManagedAppFolder: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// Human-readable app name (e.g. "Xcode")
    public let appName: String
    /// Bundle identifier if this is an app (e.g. "com.apple.dt.Xcode")
    public let bundleIdentifier: String?
    /// SF Symbol icon name
    public let iconName: String
    /// Accent color hex string
    public let colorHex: String
    /// Short description of what this folder contains
    public let description: String
    /// The primary source path (e.g. .app bundle or developer data directory)
    public let sourcePath: URL
    /// Category label (e.g. "Application", "Simulators", "DerivedData")
    public let category: String
    /// Total size on disk in bytes (bundle + all associated items for apps)
    public var size: Int64
    /// Size of the main sourcePath (.app bundle or folder itself)
    public var primarySize: Int64
    /// Whether the main source item is currently symlinked to another location
    public var isSymlink: Bool
    /// Destination of the symlink if it exists
    public var symlinkDestination: URL?
    /// Associated data folders and caches (for full app move)
    public var associatedItems: [AppAssociatedItem]

    public var formattedSize: String { ByteFormatter.format(size) }
    public var formattedPrimarySize: String { ByteFormatter.format(primarySize) }

    /// Associated data total size across all caches, containers, and support files
    public var associatedDataSize: Int64 {
        associatedItems.reduce(0) { $0 + $1.size }
    }
    public var formattedAssociatedDataSize: String { ByteFormatter.format(associatedDataSize) }

    /// True when this item is an Application (.app bundle).
    public var isAppBundle: Bool {
        sourcePath.pathExtension == "app" || category == "Application" || category == "App Bundle"
    }

    /// Total number of components (app bundle + associated data items)
    public var totalComponentsCount: Int {
        1 + associatedItems.count
    }

    /// True if the bundle and all associated items have been symlinked
    public var isFullySymlinked: Bool {
        if !isSymlink { return false }
        if associatedItems.isEmpty { return true }
        return associatedItems.allSatisfy { $0.isSymlink }
    }

    /// Returns the full destination URL on `volume` the primary item will be moved to.
    public func destinationPath(on volume: ExternalVolume) -> URL {
        if isAppBundle {
            // App bundles land in <volume>/Applications/<AppName>.app
            return volume.url
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent(sourcePath.lastPathComponent)
        } else {
            // Data folders land in <volume>/MacSweep/<AppName>/<folder>
            return volume.url
                .appendingPathComponent("MacSweep", isDirectory: true)
                .appendingPathComponent(appName, isDirectory: true)
                .appendingPathComponent(sourcePath.lastPathComponent, isDirectory: true)
        }
    }

    /// Returns the destination URL on `volume` for an associated data item.
    public func associatedDestinationPath(for item: AppAssociatedItem, on volume: ExternalVolume) -> URL {
        // e.g. <volume>/MacSweep/AppData/<AppName>/<Category>/<ItemName>
        return volume.url
            .appendingPathComponent("MacSweep", isDirectory: true)
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent(item.category, isDirectory: true)
            .appendingPathComponent(item.sourcePath.lastPathComponent)
    }

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String? = nil,
        iconName: String,
        colorHex: String,
        description: String,
        sourcePath: URL,
        category: String,
        size: Int64 = 0,
        primarySize: Int64 = 0,
        isSymlink: Bool = false,
        symlinkDestination: URL? = nil,
        associatedItems: [AppAssociatedItem] = []
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.iconName = iconName
        self.colorHex = colorHex
        self.description = description
        self.sourcePath = sourcePath
        self.category = category
        self.size = size
        self.primarySize = primarySize > 0 ? primarySize : size
        self.isSymlink = isSymlink
        self.symlinkDestination = symlinkDestination
        self.associatedItems = associatedItems
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: ManagedAppFolder, rhs: ManagedAppFolder) -> Bool { lhs.id == rhs.id }
}

/// Result of an app or folder move + symlink operation.
public struct AppFolderMoveResult: Sendable {
    public let folder: ManagedAppFolder
    public let destination: URL
    public let success: Bool
    public let errorMessage: String?
    public let bytesTransferred: Int64
    public let duration: TimeInterval
    public let componentsMovedCount: Int

    public init(
        folder: ManagedAppFolder,
        destination: URL,
        success: Bool,
        errorMessage: String?,
        bytesTransferred: Int64,
        duration: TimeInterval,
        componentsMovedCount: Int = 1
    ) {
        self.folder = folder
        self.destination = destination
        self.success = success
        self.errorMessage = errorMessage
        self.bytesTransferred = bytesTransferred
        self.duration = duration
        self.componentsMovedCount = componentsMovedCount
    }
}
