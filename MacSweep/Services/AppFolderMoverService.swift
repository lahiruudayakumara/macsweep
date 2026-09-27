import Foundation
import AppKit
import OSLog

// MARK: - Progress Types

/// Live progress update emitted during scanning.
public struct FolderScanProgress: Sendable {
    public let currentPath: String
    public let currentAppName: String
    public let currentCategory: String
    public let scannedCount: Int
    public let totalCount: Int

    public var fractionCompleted: Double {
        guard totalCount > 0 else { return 0 }
        return min(Double(scannedCount) / Double(totalCount), 1)
    }
}

/// Progress update for an app or folder move operation.
public struct FolderMoveProgress: Sendable {
    public let phase: Phase
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    public let currentFile: String
    public let completedItemsCount: Int
    public let totalItemsCount: Int

    public enum Phase: String, Sendable {
        case calculating  = "Calculating size…"
        case copying      = "Copying files…"
        case verifying    = "Verifying…"
        case symlinking   = "Creating symbolic links…"
        case cleaningUp   = "Cleaning up…"
        case done         = "Complete"
    }

    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return phase == .done ? 1 : 0 }
        return min(Double(bytesTransferred) / Double(totalBytes), 1)
    }

    public var phaseDescription: String {
        switch phase {
        case .copying:
            let pct = Int(fractionCompleted * 100)
            if totalItemsCount > 1 {
                return "Copying files… \(pct)% (\(completedItemsCount + 1) of \(totalItemsCount))"
            } else {
                return "Copying files… \(pct)%"
            }
        default:
            return phase.rawValue
        }
    }
}

// MARK: - Service

/// Service that moves full applications (app bundle + Application Support + Containers + Caches)
/// or large developer data folders to an external volume, creating symlinks at original paths
/// so macOS and apps continue running seamlessly.
public final class AppFolderMoverService: Sendable {
    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Discover Applications & Folders

    /// Discovers installed applications with their associated data footprints, as well as large developer tool folders.
    /// Calls `progressHandler` on the MainActor as each item's size is resolved.
    public func discoverManagedFolders(
        progressHandler: @escaping @MainActor @Sendable (ManagedAppFolder, FolderScanProgress) -> Void = { _, _ in }
    ) async -> [ManagedAppFolder] {
        let home = fileManager.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")

        // 1. Known developer tool and data folders
        var definitions: [(appName: String, icon: String, color: String, description: String, path: URL, category: String)] = [
            (
                "Xcode", "hammer.fill", "007AFF",
                "Compiled build products – safe to rebuild any time.",
                library.appendingPathComponent("Developer/Xcode/DerivedData"),
                "DerivedData"
            ),
            (
                "Xcode", "hammer.fill", "007AFF",
                "Downloaded iOS, watchOS, and tvOS device simulators.",
                library.appendingPathComponent("Developer/CoreSimulator/Devices"),
                "Simulators"
            ),
            (
                "Xcode", "hammer.fill", "007AFF",
                "Archived builds (.xcarchive) used for distribution.",
                library.appendingPathComponent("Developer/Xcode/Archives"),
                "Archives"
            ),
            (
                "Docker", "shippingbox.fill", "2496ED",
                "Docker VM disk image containing all images and containers.",
                library.appendingPathComponent("Containers/com.docker.docker/Data"),
                "Docker Data"
            ),
            (
                "Android Studio", "gearshape.2.fill", "3DDC84",
                "Gradle build cache and downloaded dependencies.",
                home.appendingPathComponent(".gradle"),
                "Gradle Cache"
            ),
            (
                "Android Studio", "gearshape.2.fill", "3DDC84",
                "Android SDK, emulator images, and build tools.",
                library.appendingPathComponent("Android/sdk"),
                "Android SDK"
            ),
            (
                "Homebrew", "mug.fill", "FBB040",
                "Homebrew package manager installation.",
                URL(fileURLWithPath: "/opt/homebrew"),
                "Homebrew"
            ),
            (
                "Homebrew", "mug.fill", "FBB040",
                "Homebrew formula downloads and bottle cache.",
                URL(fileURLWithPath: "/usr/local/Homebrew"),
                "Homebrew"
            ),
            (
                "Homebrew", "mug.fill", "FBB040",
                "Homebrew cache: downloaded bottles and tarballs.",
                library.appendingPathComponent("Caches/Homebrew"),
                "Homebrew Cache"
            ),
        ]

        let existingDefs = definitions.filter { fileManager.fileExists(atPath: $0.path.path) }

        // 2. Discover installed application bundles
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications")
        ]

        var appBundleURLs: [URL] = []
        for appDir in appDirs {
            if let urls = try? fileManager.contentsOfDirectory(
                at: appDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in urls where url.pathExtension == "app" {
                    // Filter system apps starting with com.apple., except Xcode
                    if let bundle = Bundle(url: url) {
                        let bundleID = bundle.bundleIdentifier ?? ""
                        if bundleID.hasPrefix("com.apple.") && bundleID != "com.apple.dt.Xcode" {
                            continue
                        }
                    }
                    appBundleURLs.append(url)
                }
            }
        }

        let totalCount = existingDefs.count + appBundleURLs.count
        var results: [ManagedAppFolder] = []
        var scannedCount = 0

        // --- Scan Applications (App Bundle + Associated Data) ---
        for url in appBundleURLs {
            if Task.isCancelled { break }
            await Task.yield()

            let name = url.deletingPathExtension().lastPathComponent
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier ?? ""

            // Check if app bundle itself is symlinked
            let isBundleSymlink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
            let bundleSymlinkDest: URL? = isBundleSymlink ? (try? URL(resolvingAliasFileAt: url)) : nil

            // Calculate app bundle size
            let bundleSize = await FileEnumerator.directorySize(url)

            // Discover associated data items in ~/Library
            let associatedItems = await discoverAssociatedData(bundleIdentifier: bundleID, appName: name)
            let associatedTotalSize = associatedItems.reduce(0) { $0 + $1.size }
            let totalAppSize = bundleSize + associatedTotalSize

            scannedCount += 1

            let isSymlinked = isBundleSymlink || (!associatedItems.isEmpty && associatedItems.allSatisfy { $0.isSymlink })

            let appFolder = ManagedAppFolder(
                appName: name,
                bundleIdentifier: bundleID.isEmpty ? nil : bundleID,
                iconName: "app.fill",
                colorHex: "007AFF",
                description: associatedItems.isEmpty
                    ? "Full Application bundle (\(ByteFormatter.format(bundleSize)))."
                    : "Full Application: bundle (\(ByteFormatter.format(bundleSize))) + \(associatedItems.count) data folders (\(ByteFormatter.format(associatedTotalSize))).",
                sourcePath: url,
                category: "Application",
                size: totalAppSize,
                primarySize: bundleSize,
                isSymlink: isSymlinked,
                symlinkDestination: bundleSymlinkDest,
                associatedItems: associatedItems
            )
            results.append(appFolder)

            let progress = FolderScanProgress(
                currentPath: url.path,
                currentAppName: name,
                currentCategory: "Application",
                scannedCount: scannedCount,
                totalCount: totalCount
            )
            await progressHandler(appFolder, progress)
        }

        // --- Scan Developer & Tool Data Folders ---
        for def in existingDefs {
            if Task.isCancelled { break }
            await Task.yield()

            let isSymlink = (try? def.path.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
            let symlinkDest: URL? = isSymlink ? (try? URL(resolvingAliasFileAt: def.path)) : nil

            let size = await FileEnumerator.directorySize(def.path)
            scannedCount += 1

            let folder = ManagedAppFolder(
                appName: def.appName,
                iconName: def.icon,
                colorHex: def.color,
                description: def.description,
                sourcePath: def.path,
                category: def.category,
                size: size,
                primarySize: size,
                isSymlink: isSymlink,
                symlinkDestination: symlinkDest,
                associatedItems: []
            )
            results.append(folder)

            let progress = FolderScanProgress(
                currentPath: def.path.path,
                currentAppName: def.appName,
                currentCategory: def.category,
                scannedCount: scannedCount,
                totalCount: totalCount
            )
            await progressHandler(folder, progress)
        }

        results.sort { $0.size > $1.size }
        return results
    }

    // MARK: - Associated Data Discovery

    /// Finds application support, containers, caches, preferences, and saved states for a given app.
    private func discoverAssociatedData(bundleIdentifier: String, appName: String) async -> [AppAssociatedItem] {
        guard !bundleIdentifier.isEmpty || !appName.isEmpty else { return [] }

        let library = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        var candidates: [(URL, String)] = []

        if !bundleIdentifier.isEmpty {
            candidates.append((library.appendingPathComponent("Application Support/\(bundleIdentifier)"), "Application Support"))
            candidates.append((library.appendingPathComponent("Containers/\(bundleIdentifier)"), "Containers"))
            candidates.append((library.appendingPathComponent("Caches/\(bundleIdentifier)"), "Caches"))
            candidates.append((library.appendingPathComponent("Logs/\(bundleIdentifier)"), "Logs"))
            candidates.append((library.appendingPathComponent("Preferences/\(bundleIdentifier).plist"), "Preferences"))
            candidates.append((library.appendingPathComponent("Saved Application State/\(bundleIdentifier).savedState"), "Saved State"))
            candidates.append((library.appendingPathComponent("HTTPStorages/\(bundleIdentifier)"), "HTTP Storage"))
        }

        if !appName.isEmpty && appName != bundleIdentifier {
            candidates.append((library.appendingPathComponent("Application Support/\(appName)"), "Application Support"))
            candidates.append((library.appendingPathComponent("Caches/\(appName)"), "Caches"))
        }

        var seenPaths = Set<String>()
        var items: [AppAssociatedItem] = []

        for (url, category) in candidates {
            let path = url.path
            guard !seenPaths.contains(path), fileManager.fileExists(atPath: path) else { continue }
            seenPaths.insert(path)

            let isSymlink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
            let symlinkDest: URL? = isSymlink ? (try? URL(resolvingAliasFileAt: url)) : nil

            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let size: Int64
            if isDir {
                size = await FileEnumerator.directorySize(url)
            } else {
                let attrs = try? fileManager.attributesOfItem(atPath: path)
                size = (attrs?[.size] as? Int64) ?? 0
            }

            // Only keep non-empty items or symlinks
            if size > 0 || isSymlink {
                items.append(AppAssociatedItem(
                    name: url.lastPathComponent,
                    sourcePath: url,
                    category: category,
                    size: size,
                    isSymlink: isSymlink,
                    symlinkDestination: symlinkDest
                ))
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Move + Symlink (Full App Relocation)

    /// Moves an application and all its associated data (or a standalone data folder) to the destination volume
    /// and replaces each location with a symbolic link.
    public func move(
        folder: ManagedAppFolder,
        toVolume destination: ExternalVolume,
        progressHandler: @escaping @MainActor @Sendable (FolderMoveProgress) -> Void = { _ in }
    ) async -> AppFolderMoveResult {
        let startedAt = Date()

        // Safety: ensure app is not running before moving
        if folder.isAppBundle, let bundleID = folder.bundleIdentifier, !bundleID.isEmpty {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if !runningApps.isEmpty {
                return failed(
                    folder: folder,
                    destination: folder.destinationPath(on: destination),
                    msg: "\(folder.appName) is currently running. Please quit \(folder.appName) before moving.",
                    started: startedAt
                )
            }
        }

        // Build list of components to transfer
        struct MoveTask {
            let source: URL
            let destination: URL
            let size: Int64
            let name: String
            let isSymlink: Bool
        }

        var tasks: [MoveTask] = []

        if folder.isAppBundle {
            // Main .app bundle
            if !folder.isSymlink {
                tasks.append(MoveTask(
                    source: folder.sourcePath,
                    destination: folder.destinationPath(on: destination),
                    size: folder.primarySize,
                    name: folder.sourcePath.lastPathComponent,
                    isSymlink: false
                ))
            }
            // Associated data folders
            for item in folder.associatedItems where !item.isSymlink {
                tasks.append(MoveTask(
                    source: item.sourcePath,
                    destination: folder.associatedDestinationPath(for: item, on: destination),
                    size: item.size,
                    name: "\(item.category): \(item.name)",
                    isSymlink: false
                ))
            }
        } else {
            // Standalone tool/developer data folder
            if !folder.isSymlink {
                tasks.append(MoveTask(
                    source: folder.sourcePath,
                    destination: folder.destinationPath(on: destination),
                    size: folder.size,
                    name: folder.sourcePath.lastPathComponent,
                    isSymlink: false
                ))
            }
        }

        guard !tasks.isEmpty else {
            return failed(
                folder: folder,
                destination: folder.destinationPath(on: destination),
                msg: "All components are already relocated to external storage.",
                started: startedAt
            )
        }

        let totalBytes = tasks.reduce(0) { $0 + $1.size }
        var bytesTransferredSoFar: Int64 = 0

        await progressHandler(FolderMoveProgress(
            phase: .calculating,
            bytesTransferred: 0,
            totalBytes: totalBytes,
            currentFile: folder.appName,
            completedItemsCount: 0,
            totalItemsCount: tasks.count
        ))

        // Execute copy and symlink for each component
        for (index, task) in tasks.enumerated() {
            let destParent = task.destination.deletingLastPathComponent()

            do {
                try fileManager.createDirectory(at: destParent, withIntermediateDirectories: true)
            } catch {
                return failed(folder: folder, destination: task.destination, msg: "Could not create destination directory: \(error.localizedDescription)", started: startedAt)
            }

            if fileManager.fileExists(atPath: task.destination.path) {
                // If it already exists, remove it cleanly to ensure a fresh move
                try? fileManager.removeItem(at: task.destination)
            }

            // Phase: Copying
            await progressHandler(FolderMoveProgress(
                phase: .copying,
                bytesTransferred: bytesTransferredSoFar,
                totalBytes: totalBytes,
                currentFile: task.name,
                completedItemsCount: index,
                totalItemsCount: tasks.count
            ))

            let copyDone = CopyDoneFlag()
            let copyError = CopyErrorBox()

            let source = task.source
            let dest = task.destination
            let fm = fileManager

            Task.detached(priority: .userInitiated) {
                do {
                    try AppFolderMoverService.safeCopyItem(at: source, to: dest, fileManager: fm)
                } catch {
                    await copyError.set(error)
                }
                await copyDone.markDone()
            }

            // Live progress polling
            while await !copyDone.isDone {
                try? await Task.sleep(nanoseconds: 300_000_000)
                let copiedCurrent = await FileEnumerator.directorySize(task.destination)
                let currentProgress = bytesTransferredSoFar + min(copiedCurrent, task.size)
                await progressHandler(FolderMoveProgress(
                    phase: .copying,
                    bytesTransferred: min(currentProgress, totalBytes),
                    totalBytes: totalBytes,
                    currentFile: task.name,
                    completedItemsCount: index,
                    totalItemsCount: tasks.count
                ))
            }

            if let err = await copyError.value {
                return failed(folder: folder, destination: task.destination, msg: "Copy failed for '\(task.name)': \(err.localizedDescription)", started: startedAt)
            }

            // Phase: Verifying
            await progressHandler(FolderMoveProgress(
                phase: .verifying,
                bytesTransferred: bytesTransferredSoFar + task.size,
                totalBytes: totalBytes,
                currentFile: task.name,
                completedItemsCount: index,
                totalItemsCount: tasks.count
            ))

            guard fileManager.fileExists(atPath: task.destination.path) else {
                return failed(folder: folder, destination: task.destination, msg: "Verification failed: '\(task.name)' not found after copy.", started: startedAt)
            }

            // Phase: Symlinking
            await progressHandler(FolderMoveProgress(
                phase: .symlinking,
                bytesTransferred: bytesTransferredSoFar + task.size,
                totalBytes: totalBytes,
                currentFile: task.name,
                completedItemsCount: index,
                totalItemsCount: tasks.count
            ))

            do {
                try fileManager.removeItem(at: task.source)
                try fileManager.createSymbolicLink(at: task.source, withDestinationURL: task.destination)
            } catch {
                try? fileManager.removeItem(at: task.destination)
                return failed(folder: folder, destination: task.destination, msg: "Symlink creation failed for '\(task.name)': \(error.localizedDescription)", started: startedAt)
            }

            bytesTransferredSoFar += task.size
        }

        await progressHandler(FolderMoveProgress(
            phase: .done,
            bytesTransferred: totalBytes,
            totalBytes: totalBytes,
            currentFile: folder.appName,
            completedItemsCount: tasks.count,
            totalItemsCount: tasks.count
        ))

        Logger.mover.info("Fully moved '\(folder.appName)' (\(tasks.count) components, \(totalBytes) bytes) to '\(destination.name)' with symlinks")

        return AppFolderMoveResult(
            folder: folder,
            destination: folder.destinationPath(on: destination),
            success: true,
            errorMessage: nil,
            bytesTransferred: totalBytes,
            duration: Date().timeIntervalSince(startedAt),
            componentsMovedCount: tasks.count
        )
    }

    // MARK: - Restore

    /// Reverses a previous move: copies items back to internal storage, removes symlinks, and cleans up external copies.
    public func restore(
        folder: ManagedAppFolder,
        progressHandler: @escaping @MainActor @Sendable (FolderMoveProgress) -> Void = { _ in }
    ) async -> AppFolderMoveResult {
        let startedAt = Date()

        // Safety: ensure app is not running
        if folder.isAppBundle, let bundleID = folder.bundleIdentifier, !bundleID.isEmpty {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if !runningApps.isEmpty {
                return failed(
                    folder: folder,
                    destination: folder.sourcePath,
                    msg: "\(folder.appName) is currently running. Please quit \(folder.appName) before restoring.",
                    started: startedAt
                )
            }
        }

        // Collect all symlinked items to restore
        struct RestoreTask {
            let localSymlinkURL: URL
            let externalURL: URL
            let size: Int64
            let name: String
        }

        var tasks: [RestoreTask] = []

        if folder.isAppBundle {
            // Check main bundle
            if folder.isSymlink, let dest = (try? URL(resolvingAliasFileAt: folder.sourcePath)) ?? folder.symlinkDestination {
                tasks.append(RestoreTask(
                    localSymlinkURL: folder.sourcePath,
                    externalURL: dest,
                    size: folder.primarySize,
                    name: folder.sourcePath.lastPathComponent
                ))
            }
            // Check associated items
            for item in folder.associatedItems {
                if item.isSymlink, let dest = (try? URL(resolvingAliasFileAt: item.sourcePath)) ?? item.symlinkDestination {
                    tasks.append(RestoreTask(
                        localSymlinkURL: item.sourcePath,
                        externalURL: dest,
                        size: item.size,
                        name: item.name
                    ))
                }
            }
        } else {
            // Standalone folder
            if folder.isSymlink, let dest = (try? URL(resolvingAliasFileAt: folder.sourcePath)) ?? folder.symlinkDestination {
                tasks.append(RestoreTask(
                    localSymlinkURL: folder.sourcePath,
                    externalURL: dest,
                    size: folder.size,
                    name: folder.sourcePath.lastPathComponent
                ))
            }
        }

        guard !tasks.isEmpty else {
            return failed(
                folder: folder,
                destination: folder.sourcePath,
                msg: "No components are currently symlinked to an external drive.",
                started: startedAt
            )
        }

        let totalBytes = tasks.reduce(0) { $0 + $1.size }
        var bytesTransferredSoFar: Int64 = 0

        for (index, task) in tasks.enumerated() {
            await progressHandler(FolderMoveProgress(
                phase: .copying,
                bytesTransferred: bytesTransferredSoFar,
                totalBytes: totalBytes,
                currentFile: task.name,
                completedItemsCount: index,
                totalItemsCount: tasks.count
            ))

            let tempDest = task.localSymlinkURL.deletingLastPathComponent()
                .appendingPathComponent(".\(task.localSymlinkURL.lastPathComponent)_restore_tmp")

            if fileManager.fileExists(atPath: tempDest.path) {
                try? fileManager.removeItem(at: tempDest)
            }

            let restoreDone = CopyDoneFlag()
            let restoreError = CopyErrorBox()

            let externalURL = task.externalURL
            let fm = fileManager

            Task.detached(priority: .userInitiated) {
                do {
                    try AppFolderMoverService.safeCopyItem(at: externalURL, to: tempDest, fileManager: fm)
                } catch {
                    await restoreError.set(error)
                }
                await restoreDone.markDone()
            }

            while await !restoreDone.isDone {
                try? await Task.sleep(nanoseconds: 300_000_000)
                let copiedCurrent = await FileEnumerator.directorySize(tempDest)
                let currentProgress = bytesTransferredSoFar + min(copiedCurrent, task.size)
                await progressHandler(FolderMoveProgress(
                    phase: .copying,
                    bytesTransferred: min(currentProgress, totalBytes),
                    totalBytes: totalBytes,
                    currentFile: task.name,
                    completedItemsCount: index,
                    totalItemsCount: tasks.count
                ))
            }

            if let err = await restoreError.value {
                return failed(folder: folder, destination: task.localSymlinkURL, msg: "Copy back failed for '\(task.name)': \(err.localizedDescription)", started: startedAt)
            }

            await progressHandler(FolderMoveProgress(
                phase: .symlinking,
                bytesTransferred: bytesTransferredSoFar + task.size,
                totalBytes: totalBytes,
                currentFile: task.name,
                completedItemsCount: index,
                totalItemsCount: tasks.count
            ))

            do {
                try fileManager.removeItem(at: task.localSymlinkURL)
                try fileManager.moveItem(at: tempDest, to: task.localSymlinkURL)
                try? fileManager.removeItem(at: task.externalURL)
            } catch {
                try? fileManager.removeItem(at: tempDest)
                return failed(folder: folder, destination: task.localSymlinkURL, msg: "Restore failed for '\(task.name)': \(error.localizedDescription)", started: startedAt)
            }

            bytesTransferredSoFar += task.size
        }

        await progressHandler(FolderMoveProgress(
            phase: .done,
            bytesTransferred: totalBytes,
            totalBytes: totalBytes,
            currentFile: folder.appName,
            completedItemsCount: tasks.count,
            totalItemsCount: tasks.count
        ))

        Logger.mover.info("Restored '\(folder.appName)' (\(tasks.count) components) back to internal drive")

        return AppFolderMoveResult(
            folder: folder,
            destination: folder.sourcePath,
            success: true,
            errorMessage: nil,
            bytesTransferred: totalBytes,
            duration: Date().timeIntervalSince(startedAt),
            componentsMovedCount: tasks.count
        )
    }

    // MARK: - Helpers

    /// Safely copies an item (file or directory tree) from source to destination,
    /// skipping non-transferrable files like UNIX domain sockets (.sock) and FIFOs.
    public static func safeCopyItem(at srcURL: URL, to dstURL: URL, fileManager: FileManager) throws {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: srcURL.path, isDirectory: &isDir) else {
            throw MacSweepError.fileNotFound(path: srcURL.path)
        }

        // If it's a symbolic link itself, copy/recreate the symlink
        if let res = try? srcURL.resourceValues(forKeys: [.isSymbolicLinkKey]), res.isSymbolicLink == true {
            let dest = try fileManager.destinationOfSymbolicLink(atPath: srcURL.path)
            try fileManager.createSymbolicLink(atPath: dstURL.path, withDestinationPath: dest)
            return
        }

        // If it's a regular file or special node:
        if !isDir.boolValue {
            if srcURL.pathExtension == "sock" { return }
            if let attrs = try? fileManager.attributesOfItem(atPath: srcURL.path),
               let type = attrs[.type] as? FileAttributeType,
               type == .typeSocket {
                return
            }
            try fileManager.copyItem(at: srcURL, to: dstURL)
            return
        }

        // It is a directory: create destination directory
        try fileManager.createDirectory(at: dstURL, withIntermediateDirectories: true)

        let contents = (try? fileManager.contentsOfDirectory(
            at: srcURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileResourceTypeKey],
            options: []
        )) ?? []

        for child in contents {
            let childDst = dstURL.appendingPathComponent(child.lastPathComponent)

            // Skip socket files and special pipes
            if child.pathExtension == "sock" { continue }
            if let resourceValues = try? child.resourceValues(forKeys: [.fileResourceTypeKey]),
               resourceValues.fileResourceType == .socket {
                continue
            }
            if let attrs = try? fileManager.attributesOfItem(atPath: child.path),
               let type = attrs[.type] as? FileAttributeType,
               type == .typeSocket {
                continue
            }

            try safeCopyItem(at: child, to: childDst, fileManager: fileManager)
        }
    }

    private func failed(folder: ManagedAppFolder, destination: URL, msg: String, started: Date) -> AppFolderMoveResult {
        Logger.mover.error("AppFolderMover error: \(msg, privacy: .public)")
        return AppFolderMoveResult(
            folder: folder,
            destination: destination,
            success: false,
            errorMessage: msg,
            bytesTransferred: 0,
            duration: Date().timeIntervalSince(started)
        )
    }
}

// MARK: - Copy Progress Helpers (private actors)

private actor CopyDoneFlag {
    private(set) var isDone = false
    func markDone() { isDone = true }
}

private actor CopyErrorBox {
    private(set) var value: (any Error)?
    func set(_ error: any Error) { value = error }
}
