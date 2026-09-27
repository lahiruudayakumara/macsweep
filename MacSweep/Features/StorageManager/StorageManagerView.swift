import SwiftUI

// MARK: - Main View

public struct StorageManagerView: View {
    @StateObject private var viewModel: StorageManagerViewModel

    public init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: StorageManagerViewModel(environment: environment))
    }

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .idle:
                EmptyStateView(
                    title: "Storage Manager",
                    subtitle: "View all your internal and external drives, their usage, and the largest folders on each volume.",
                    iconName: "externaldrive.fill",
                    buttonTitle: "Load Volumes",
                    buttonAction: { Task { await viewModel.load() } }
                )
            case .loading:
                loadingState
            case .results:
                resultsState
            case .error(let msg):
                ErrorView(message: msg) {
                    viewModel.viewState = .idle
                }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
            Text("Scanning volumes…")
                .font(.system(size: 14))
                .foregroundColor(.msSecondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    private var resultsState: some View {
        HSplitView {
            volumeList
                .frame(minWidth: 240, idealWidth: 260, maxWidth: 300)

            volumeDetailPanel
                .frame(minWidth: 400)
        }
    }

    // MARK: - Volume List (left panel)

    private var volumeList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Volumes")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.msLabel)
                Spacer()
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Refresh volumes")
            }
            .padding(12)
            .background(Color.msSecondaryBackground)

            Divider()

            List(viewModel.volumes, id: \.id, selection: $viewModel.selectedVolumeID) { volume in
                StorageVolumeRow(
                    volume: volume,
                    isSelected: volume.id == viewModel.selectedVolumeID
                )
                .tag(volume.id)
            }
            .listStyle(.sidebar)
            .onChange(of: viewModel.selectedVolumeID) { _, newID in
                if let vol = viewModel.volumes.first(where: { $0.id == newID }) {
                    Task { await viewModel.selectVolume(vol) }
                }
            }
        }
    }

    // MARK: - Volume Detail (right panel)

    @ViewBuilder
    private var volumeDetailPanel: some View {
        if let volume = viewModel.selectedVolume {
            VStack(spacing: 0) {
                volumeDetailHeader(volume)
                Divider()

                if viewModel.loadingVolumeID == volume.id {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.2)
                        Text("Calculating folder sizes…")
                            .font(.system(size: 13))
                            .foregroundColor(.msSecondaryLabel)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    directoryList(for: volume)
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 48))
                    .foregroundColor(.msSecondaryLabel.opacity(0.35))
                Text("Select a volume")
                    .font(.system(size: 14))
                    .foregroundColor(.msSecondaryLabel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func volumeDetailHeader(_ volume: ExternalVolume) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.msAccent.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: volume.isExternal ? "externaldrive.fill" : "internaldrive.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.msAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(volume.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.msLabel)
                        Text(volume.isExternal ? "External" : "Internal")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(volume.isExternal ? .msAccent : .msSecondaryLabel)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((volume.isExternal ? Color.msAccent : Color.msSecondaryLabel).opacity(0.12), in: Capsule())
                    }
                    Text("\(volume.formattedAvailable) free of \(volume.formattedTotal)")
                        .font(.system(size: 12))
                        .foregroundColor(.msSecondaryLabel)
                }
                Spacer()
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(volume.usedPercentage > 0.9
                              ? Color.msHighRisk
                              : volume.usedPercentage > 0.75
                                ? Color.msCaution
                                : Color.msAccent)
                        .frame(width: geo.size.width * CGFloat(min(volume.usedPercentage, 1)))
                }
            }
            .frame(height: 8)

            HStack {
                usageLegendDot(color: .msAccent, label: "Used \(volume.formattedUsed)")
                usageLegendDot(color: Color.primary.opacity(0.15), label: "Free \(volume.formattedAvailable)")
                Spacer()
                Text("\(Int(volume.usedPercentage * 100))% used")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.msSecondaryLabel)
            }
        }
        .padding(16)
        .background(Color.msSecondaryBackground)
    }

    private func usageLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundColor(.msSecondaryLabel)
        }
    }

    private func directoryList(for volume: ExternalVolume) -> some View {
        let contents = viewModel.selectedVolumeContents
        return Group {
            if contents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundColor(.msSecondaryLabel.opacity(0.4))
                    Text("No readable contents found")
                        .font(.system(size: 13))
                        .foregroundColor(.msSecondaryLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let maxSize = contents.first?.size ?? 1
                List(contents) { dir in
                    DirectoryRow(dir: dir, maxSize: maxSize, volumeUsed: volume.usedCapacity)
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Volume Row

private struct StorageVolumeRow: View {
    let volume: ExternalVolume
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: volume.isExternal ? "externaldrive.fill" : "internaldrive.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .msAccent : .msSecondaryLabel)
                Text(volume.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.msLabel)
                    .lineLimit(1)
                Spacer()
                if volume.isReadOnly {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.msSecondaryLabel)
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
            .frame(height: 3)

            Text("\(volume.formattedAvailable) free • \(volume.formattedTotal)")
                .font(.system(size: 10))
                .foregroundColor(.msSecondaryLabel)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Directory Row

private struct DirectoryRow: View {
    let dir: VolumeDirectory
    let maxSize: Int64
    let volumeUsed: Int64

    private var barFraction: Double {
        guard maxSize > 0 else { return 0 }
        return Double(dir.size) / Double(maxSize)
    }

    private var volumeFraction: Double {
        guard volumeUsed > 0 else { return 0 }
        return Double(dir.size) / Double(volumeUsed)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: dir.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 16))
                .foregroundColor(dir.isDirectory ? .msAccent : .msSecondaryLabel)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dir.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.msLabel)
                        .lineLimit(1)
                    Spacer()
                    Text(dir.formattedSize)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.msLabel)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.07))
                        Capsule()
                            .fill(Color.msAccent.opacity(0.75))
                            .frame(width: geo.size.width * CGFloat(min(barFraction, 1)))
                    }
                }
                .frame(height: 4)

                HStack {
                    if dir.isDirectory && dir.itemCount > 0 {
                        Text("\(dir.itemCount) items")
                    }
                    Spacer()
                    Text("\(Int(volumeFraction * 100))% of volume")
                }
                .font(.system(size: 10))
                .foregroundColor(.msSecondaryLabel)
            }
        }
        .padding(.vertical, 4)
    }
}
