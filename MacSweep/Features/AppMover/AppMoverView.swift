import SwiftUI
import AppKit

// MARK: - Main View

public struct AppMoverView: View {
    @StateObject private var viewModel: AppMoverViewModel

    public init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: AppMoverViewModel(environment: environment))
    }

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .idle:
                idleState
            case .scanning:
                // Show scanning UI — with partial results streamed live on the left
                scanningState
            case .results:
                resultsState
            case .moving:
                movingState
            case .moveDone:
                moveResultState
            case .error(let msg):
                errorState(msg)
            }
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .move:
                moveConfirmSheet
            case .restore:
                restoreConfirmSheet
            }
        }
    }

    // MARK: - Idle

    private var idleState: some View {
        EmptyStateView(
            title: "App Mover",
            subtitle: "Move entire applications — including their .app bundles, Application Support, Containers, and Caches — or large developer tool folders to an external drive. A symbolic link is left behind so every app keeps working perfectly.",
            iconName: "externaldrive.badge.plus",
            buttonTitle: "Scan Applications & Folders",
            buttonAction: { Task { await viewModel.scan() } }
        )
    }

    // MARK: - Scanning State (rich live UI)

    private var scanningState: some View {
        HSplitView {
            // Left: partial results appear here in real time
            VStack(spacing: 0) {
                scanningListHeader
                Divider()
                if viewModel.folders.isEmpty {
                    scanningEmptyList
                } else {
                    scanningLiveList
                }
            }
            .frame(minWidth: 320, idealWidth: 350, maxWidth: 390)

            // Right: scanning detail panel
            scanningDetailPanel
                .frame(minWidth: 360)
        }
    }

    private var scanningListHeader: some View {
        HStack(spacing: 10) {
            ScanningPulseDot()

            VStack(alignment: .leading, spacing: 1) {
                Text("Scanning Applications & Folders…")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.msLabel)
                if let p = viewModel.scanProgress {
                    Text("\(p.scannedCount) of \(p.totalCount) checked")
                        .font(.system(size: 11))
                        .foregroundColor(.msSecondaryLabel)
                } else {
                    Text("Starting up…")
                        .font(.system(size: 11))
                        .foregroundColor(.msSecondaryLabel)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.msSecondaryBackground)
    }

    private var scanningEmptyList: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .scaleEffect(1.1)
            Text("Looking for applications and data folders…")
                .font(.system(size: 12))
                .foregroundColor(.msSecondaryLabel)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningLiveList: some View {
        List(viewModel.folders) { folder in
            AppMoverItemRow(folder: folder)
                .padding(.vertical, 2)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
        }
        .listStyle(.sidebar)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.folders.map(\.id))
    }

    private var scanningDetailPanel: some View {
        VStack(spacing: 32) {
            Spacer()

            // Central icon with rotating ring
            ZStack {
                Circle()
                    .stroke(Color.msAccent.opacity(0.12), lineWidth: 3)
                    .frame(width: 110, height: 110)

                ScanSpinnerRing(progress: viewModel.scanProgress.map {
                    $0.totalCount > 0 ? Double($0.scannedCount) / Double($0.totalCount) : 0
                } ?? 0)
                .frame(width: 110, height: 110)

                ZStack {
                    Circle()
                        .fill(Color.msAccent.opacity(0.1))
                        .frame(width: 76, height: 76)
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.msAccent)
                }
            }

            // Current scan target
            VStack(spacing: 8) {
                Text("Calculating Footprint")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.msLabel)

                if let p = viewModel.scanProgress {
                    VStack(spacing: 4) {
                        Text(p.currentAppName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.msAccent)
                        Text("· \(p.currentCategory) ·")
                            .font(.system(size: 12))
                            .foregroundColor(.msSecondaryLabel)

                        Text(p.currentPath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.msSecondaryLabel.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 320)
                    }
                } else {
                    Text("Preparing scan…")
                        .font(.system(size: 13))
                        .foregroundColor(.msSecondaryLabel)
                }
            }

            // Progress bar
            if let p = viewModel.scanProgress, p.totalCount > 0 {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.msAccent, Color.msAccent.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(p.fractionCompleted))
                                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: p.fractionCompleted)
                        }
                    }
                    .frame(maxWidth: 320, maxHeight: 6)

                    Text("\(p.scannedCount) of \(p.totalCount) items checked")
                        .font(.system(size: 11))
                        .foregroundColor(.msSecondaryLabel)
                }
            }

            // Live discovery chips
            if !viewModel.folders.isEmpty {
                VStack(spacing: 6) {
                    Text("Found so far:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.msSecondaryLabel)

                    let topFolders = Array(viewModel.folders.prefix(4))
                    FlowLayout(spacing: 6) {
                        ForEach(topFolders) { f in
                            HStack(spacing: 5) {
                                Image(systemName: f.isAppBundle ? "app.badge.checkmark" : f.iconName)
                                    .font(.system(size: 10))
                                Text("\(f.appName) · \(f.formattedSize)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.msAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.msAccent.opacity(0.1), in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.4), value: topFolders.map(\.id))
                    .frame(maxWidth: 320)
                }
            }

            Spacer()

            Text("Scanning calculates full app bundle and associated data folder sizes. Results stream live.")
                .font(.system(size: 11))
                .foregroundColor(.msSecondaryLabel.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results (main UI)

    private var resultsState: some View {
        HSplitView {
            VStack(spacing: 0) {
                folderListHeader
                searchAndFilterBar
                Divider()
                folderList
            }
            .frame(minWidth: 320, idealWidth: 350, maxWidth: 400)

            if let folder = viewModel.selectedFolder {
                folderDetail(folder)
                    .frame(minWidth: 380)
            } else {
                noSelectionPlaceholder
                    .frame(minWidth: 380)
            }
        }
    }

    private var folderListHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("App Mover")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.msLabel)
                Text("\(viewModel.folders.count) items • \(ByteFormatter.format(viewModel.totalSavings)) movable")
                    .font(.system(size: 11))
                    .foregroundColor(.msSecondaryLabel)
            }
            Spacer()
            Button {
                Task { await viewModel.scan() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Rescan applications and folders")
        }
        .padding(14)
        .background(Color.msSecondaryBackground)
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.msSecondaryLabel)
                TextField("Search apps or folders…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.msSecondaryLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))

            // Filter segmented control
            Picker("Filter", selection: $viewModel.selectedFilter) {
                Text("All (\(viewModel.folders.count))").tag(AppMoverViewModel.Filter.all)
                Text("Apps (\(viewModel.applicationsCount))").tag(AppMoverViewModel.Filter.applications)
                Text("Data (\(viewModel.dataFoldersCount))").tag(AppMoverViewModel.Filter.dataFolders)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.msSecondaryBackground.opacity(0.6))
    }

    private var folderList: some View {
        List(viewModel.filteredFolders, selection: $viewModel.selectedFolderID) { folder in
            AppMoverItemRow(folder: folder)
                .tag(folder.id)
                .padding(.vertical, 2)
        }
        .listStyle(.sidebar)
    }

    private var noSelectionPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 52))
                .foregroundColor(.msSecondaryLabel.opacity(0.4))
            Text("Select an app or folder on the left")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.msSecondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Folder Detail

    private func folderDetail(_ folder: ManagedAppFolder) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                detailHeader(folder)

                // Components breakdown for full apps
                if folder.isAppBundle && !folder.associatedItems.isEmpty {
                    componentsBreakdownCard(folder)
                }

                if folder.isSymlink {
                    symlinkStatusCard(folder)
                } else {
                    volumePicker(folder)
                }
                Spacer()
            }
            .padding(24)
        }
    }

    private func detailHeader(_ folder: ManagedAppFolder) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if folder.isAppBundle {
                ApplicationIconView(bundleURL: folder.sourcePath, size: 56)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: folder.colorHex).opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: folder.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: folder.colorHex))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(folder.appName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.msLabel)
                    Text(folder.isAppBundle ? "Full Application" : folder.category)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.msAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.msAccent.opacity(0.12), in: Capsule())
                }
                Text(folder.description)
                    .font(.system(size: 12))
                    .foregroundColor(.msSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Label(folder.formattedSize, systemImage: "internaldrive")
                    Label(folder.sourcePath.path, systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.system(size: 11))
                .foregroundColor(.msSecondaryLabel)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.msSecondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Components Breakdown Card (Full App Move)

    private func componentsBreakdownCard(_ folder: ManagedAppFolder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.3.layers.3d.down.right")
                    .foregroundColor(.msAccent)
                Text("App Components & Associated Data")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.msLabel)
                Spacer()
                Text("\(folder.totalComponentsCount) items • \(folder.formattedSize)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.msSecondaryLabel)
            }

            Divider()

            // Application bundle row
            HStack(spacing: 10) {
                Image(systemName: "app.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.msAccent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Application Bundle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.msLabel)
                    Text(folder.sourcePath.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.msSecondaryLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(folder.formattedPrimarySize)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.msLabel)
            }
            .padding(.vertical, 2)

            // Associated data folders
            ForEach(folder.associatedItems) { item in
                HStack(spacing: 10) {
                    Image(systemName: iconForCategory(item.category))
                        .font(.system(size: 13))
                        .foregroundColor(.msSecondaryLabel)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(item.category)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.msLabel)
                            Text(item.name)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.msSecondaryLabel)
                                .lineLimit(1)
                        }
                        Text(item.sourcePath.path)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.msSecondaryLabel.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(item.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.msSecondaryLabel)
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.msAccent)
                Text("All components above will be moved to external storage and symlinked transparently.")
                    .font(.system(size: 10))
                    .foregroundColor(.msSecondaryLabel)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Application Support": return "folder.badge.gearshape"
        case "Containers": return "shippingbox"
        case "Caches": return "cylinder.split.1x2"
        case "Logs": return "doc.text"
        case "Preferences": return "slider.horizontal.3"
        case "Saved State": return "clock.arrow.circlepath"
        case "HTTP Storage": return "network"
        default: return "folder"
        }
    }

    private func symlinkStatusCard(_ folder: ManagedAppFolder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.msSafe)
                Text("Currently on External Drive")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.msLabel)
            }
            if let dest = folder.symlinkDestination {
                Text("→ \(dest.path)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.msSecondaryLabel)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Button {
                viewModel.confirmingRestore = true
            } label: {
                Label("Restore to Internal Drive", systemImage: "internaldrive.badge.minus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(14)
        .background(Color.msSafe.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.msSafe.opacity(0.25), lineWidth: 1)
        )
    }

    private func volumePicker(_ folder: ManagedAppFolder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.msAccent)
                Text("Choose Destination Drive")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.msLabel)
            }

            // Info banner
            if let selectedVol = viewModel.selectedVolume {
                let destPath = folder.destinationPath(on: selectedVol)
                HStack(spacing: 8) {
                    Image(systemName: folder.isAppBundle ? "tray.and.arrow.down.fill" : "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.msAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.isAppBundle ? "Full App Move to External Applications" : "Will be placed in MacSweep folder")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.msAccent)
                        Text(destPath.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.msSecondaryLabel)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.msAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.msAccent.opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.spring(response: 0.3), value: selectedVol.id)
            }

            if viewModel.externalVolumes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .foregroundColor(.msCaution)
                    Text("No writable external drives found. Connect a drive and click Rescan.")
                        .font(.system(size: 12))
                        .foregroundColor(.msSecondaryLabel)
                }
                .padding(12)
                .background(Color.msCaution.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(viewModel.externalVolumes) { volume in
                    VolumePickerRow(
                        volume: volume,
                        isSelected: volume.id == viewModel.selectedVolumeID,
                        requiredSpace: folder.size
                    ) {
                        viewModel.selectedVolumeID = volume.id
                    }
                }

                if let selectedVol = viewModel.selectedVolume {
                    let hasEnough = selectedVol.availableCapacity >= folder.size

                    if !hasEnough {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.msHighRisk)
                                .font(.system(size: 11))
                            Text("\(selectedVol.name) only has \(selectedVol.formattedAvailable) free. This item needs \(folder.formattedSize).")
                                .font(.system(size: 11))
                                .foregroundColor(.msHighRisk)
                        }
                        .padding(10)
                        .background(Color.msHighRisk.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }

                    PrimaryButton(
                        title: hasEnough
                            ? (folder.isAppBundle ? "Move Complete App to \(selectedVol.name)" : "Move Folder to \(selectedVol.name)")
                            : "Not Enough Space on \(selectedVol.name)",
                        iconName: hasEnough ? "externaldrive.badge.plus" : "exclamationmark.triangle",
                        isLoading: false
                    ) {
                        if hasEnough { viewModel.confirmingMove = true }
                    }
                    .disabled(!hasEnough)
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(Color.msSecondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Moving State (rich progress UI)

    private var movingState: some View {
        VStack(spacing: 28) {
            Spacer()

            if let progress = viewModel.moveProgress {
                ZStack {
                    Circle()
                        .stroke(Color.msAccent.opacity(0.12), lineWidth: 4)
                        .frame(width: 100, height: 100)

                    if progress.phase == .copying {
                        Circle()
                            .trim(from: 0, to: CGFloat(progress.fractionCompleted))
                            .stroke(
                                LinearGradient(colors: [.msAccent, .msAccent.opacity(0.4)],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress.fractionCompleted)
                    } else {
                        IndeterminateSpinner(color: .msAccent, lineWidth: 4, size: 100)
                    }

                    Image(systemName: phaseIcon(progress.phase))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.msAccent)
                        .transition(.scale.combined(with: .opacity))
                        .id(progress.phase)
                        .animation(.spring(response: 0.3), value: progress.phase.rawValue)
                }

                VStack(spacing: 6) {
                    Text(progress.phaseDescription)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.msLabel)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: progress.phase.rawValue)

                    if progress.phase == .copying && progress.totalBytes > 0 {
                        Text("\(ByteFormatter.format(progress.bytesTransferred))  of  \(ByteFormatter.format(progress.totalBytes))")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.msSecondaryLabel)
                    }

                    if !progress.currentFile.isEmpty && progress.phase == .copying {
                        Text(progress.currentFile)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.msSecondaryLabel.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 320)
                    }
                }

                if progress.phase == .copying && progress.totalBytes > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.msAccent, Color.msAccent.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(progress.fractionCompleted))
                                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress.fractionCompleted)
                        }
                    }
                    .frame(maxWidth: 360, maxHeight: 6)
                }

                movePhaseSteps(currentPhase: progress.phase)

            } else {
                IndeterminateSpinner(color: .msAccent, lineWidth: 4, size: 80)
                Text("Preparing…")
                    .font(.system(size: 15))
                    .foregroundColor(.msSecondaryLabel)
            }

            Spacer()

            Text("Do not disconnect the external drive during the transfer.")
                .font(.system(size: 11))
                .foregroundColor(.msCaution.opacity(0.8))
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    private func phaseIcon(_ phase: FolderMoveProgress.Phase) -> String {
        switch phase {
        case .calculating:  return "ruler"
        case .copying:      return "arrow.right.circle.fill"
        case .verifying:    return "checkmark.shield"
        case .symlinking:   return "link"
        case .cleaningUp:   return "trash"
        case .done:         return "checkmark.circle.fill"
        }
    }

    private func movePhaseSteps(currentPhase: FolderMoveProgress.Phase) -> some View {
        let phases: [FolderMoveProgress.Phase] = [.calculating, .copying, .verifying, .symlinking, .done]
        let currentIndex = phases.firstIndex(where: { $0.rawValue == currentPhase.rawValue }) ?? 0

        return HStack(spacing: 0) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                HStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(index <= currentIndex ? Color.msAccent : Color.primary.opacity(0.1))
                            .frame(width: 22, height: 22)
                        if index < currentIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        } else if index == currentIndex {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .animation(.spring(response: 0.4), value: currentIndex)

                    if index < phases.count - 1 {
                        Rectangle()
                            .fill(index < currentIndex ? Color.msAccent : Color.primary.opacity(0.1))
                            .frame(height: 2)
                            .animation(.spring(response: 0.4), value: currentIndex)
                    }
                }
            }
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Move Result

    private var moveResultState: some View {
        Group {
            if let result = viewModel.lastMoveResult {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill((result.success ? Color.msSafe : Color.msHighRisk).opacity(0.14))
                            .frame(width: 96, height: 96)
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(result.success ? .msSafe : .msHighRisk)
                    }

                    VStack(spacing: 6) {
                        Text(result.success ? "Move Complete!" : "Move Failed")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.msLabel)
                        if result.success {
                            if result.folder.isAppBundle {
                                Text("Successfully moved \(result.folder.appName) and its data (\(ByteFormatter.format(result.bytesTransferred))) to external drive.\nSymbolic links were created — \(result.folder.appName) will work normally from the external drive.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.msSecondaryLabel)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Moved \(ByteFormatter.format(result.bytesTransferred)) to external drive.\nA symbolic link was created — \(result.folder.appName) will work normally.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.msSecondaryLabel)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            Text(result.errorMessage ?? "An unknown error occurred.")
                                .font(.system(size: 13))
                                .foregroundColor(.msCaution)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Button("Done") { viewModel.resetAfterMove() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        ErrorView(message: message) {
            viewModel.viewState = .idle
        }
    }

    // MARK: - Confirm Sheets

    private var moveConfirmSheet: some View {
        let folder = viewModel.selectedFolder
        let volume = viewModel.selectedVolume
        let isApp = folder?.isAppBundle == true
        let appName = folder?.appName ?? ""
        let destPath = folder.flatMap { f in volume.map { v in f.destinationPath(on: v).path } } ?? ""

        let title = isApp
            ? "Move \(appName) & All Data to External Drive?"
            : "Move \(appName) Folder?"

        let message = isApp
            ? "This will move \(appName) and all its associated data (\(folder?.formattedSize ?? "") across \(folder?.totalComponentsCount ?? 1) components) to:\n\(destPath)\n\nSymbolic links will be created for the app bundle and all Library folders (Application Support, Containers, Caches) so macOS and \(appName) continue to launch and function normally.\n\nKeep '\(volume?.name ?? "the drive")' connected when running \(appName)."
            : "This will move \(folder?.category ?? "folder") (\(folder?.formattedSize ?? "")) to:\n\(destPath)\n\nA symbolic link will be created at the original location so \(appName) continues to work normally.\n\nKeep '\(volume?.name ?? "the drive")' connected while in use."

        return ConfirmationDialog(
            title: title,
            message: message,
            confirmTitle: isApp ? "Move Complete App" : "Move to External Drive",
            isDestructive: false,
            onConfirm: { Task { await viewModel.moveToExternal() } },
            onCancel: { viewModel.confirmingMove = false }
        )
    }

    private var restoreConfirmSheet: some View {
        ConfirmationDialog(
            title: "Restore to Internal Drive?",
            message: "This will copy all components back from the external drive to their original internal locations and remove the symbolic links. Make sure you have enough internal storage first.",
            confirmTitle: "Restore to Internal Drive",
            isDestructive: false,
            onConfirm: { Task { await viewModel.restoreToInternal() } },
            onCancel: { viewModel.confirmingRestore = false }
        )
    }
}

// MARK: - App Mover Item Row

private struct AppMoverItemRow: View {
    let folder: ManagedAppFolder

    var body: some View {
        HStack(spacing: 10) {
            if folder.isAppBundle {
                ApplicationIconView(bundleURL: folder.sourcePath, size: 32)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: folder.colorHex).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: folder.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: folder.colorHex))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(folder.appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.msLabel)
                    Text(folder.isAppBundle ? "Full App" : folder.category)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.msSecondaryLabel)
                }
                HStack(spacing: 6) {
                    Text(folder.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.msSecondaryLabel)
                    if folder.isAppBundle && !folder.associatedItems.isEmpty {
                        Text("• \(folder.totalComponentsCount) parts")
                            .font(.system(size: 10))
                            .foregroundColor(.msSecondaryLabel.opacity(0.8))
                    }
                }
            }

            Spacer()

            if folder.isSymlink {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.msSafe)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Volume Picker Row

private struct VolumePickerRow: View {
    let volume: ExternalVolume
    let isSelected: Bool
    let requiredSpace: Int64
    let onTap: () -> Void

    private var hasEnoughSpace: Bool { volume.availableCapacity >= requiredSpace }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .msAccent : .msSecondaryLabel)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(volume.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.msLabel)
                    Spacer()
                    if !hasEnoughSpace {
                        Label("Not enough space", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.msHighRisk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.msHighRisk.opacity(0.10), in: Capsule())
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(volume.usedPercentage > 0.9 ? Color.msHighRisk : Color.msAccent)
                            .frame(width: geo.size.width * CGFloat(min(volume.usedPercentage, 1)))
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(volume.formattedAvailable) available")
                        .foregroundColor(hasEnoughSpace ? .msSecondaryLabel : .msHighRisk)
                    Spacer()
                    Text(volume.formattedTotal)
                        .foregroundColor(.msSecondaryLabel)
                }
                .font(.system(size: 10))
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.msAccent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.msAccent.opacity(0.08) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected ? Color.msAccent.opacity(0.45) : Color.primary.opacity(0.1),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Scanning Pulse Dot

private struct ScanningPulseDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.msAccent.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(pulsing ? 1.6 : 1)
                .opacity(pulsing ? 0 : 1)
            Circle()
                .fill(Color.msAccent)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Scan Spinner Ring

private struct ScanSpinnerRing: View {
    let progress: Double
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.msAccent.opacity(0.1), lineWidth: 4)

            if progress > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.msAccent.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
            }

            Circle()
                .trim(from: 0, to: 0.18)
                .stroke(Color.msAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Indeterminate Spinner

private struct IndeterminateSpinner: View {
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows
    }
}
