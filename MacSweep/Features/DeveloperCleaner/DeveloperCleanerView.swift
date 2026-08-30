import SwiftUI

public struct DeveloperCleanerView: View {
    @State private var selectedItemIDs: Set<String> = ["xcode-derived-data", "xcode-archives", "xcode-simulators"]
    @State private var selectedDestinationID = "external-t7"
    @State private var showDriveManager = false
    @State private var showApproval = false
    @State private var showDemoConfirmation = false

    private let tools = DeveloperStoragePreview.tools
    private let destinations = DeveloperStoragePreview.destinations

    public init(environment: AppEnvironment) {}

    private var selectedItems: [DeveloperStorageItem] {
        tools.flatMap(\.items).filter { selectedItemIDs.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    private var selectedDestination: DeveloperStorageDestination {
        destinations.first { $0.id == selectedDestinationID } ?? destinations[0]
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    previewNotice
                    storageOverview
                    destinationSection
                    toolSections
                }
                .padding(20)
                .frame(maxWidth: 1040, alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            Divider()
            actionBar
        }
        .sheet(isPresented: $showDriveManager) { driveManagerSheet }
        .sheet(isPresented: $showApproval) { approvalSheet }
        .alert("Demo plan approved", isPresented: $showDemoConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This screen uses sample data only. No files were moved or removed.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.msAccent.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.msAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Developer Storage")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.msLabel)
                Text("Review developer files and plan where they should go")
                    .font(.system(size: 12))
                    .foregroundColor(.msSecondaryLabel)
            }

            Spacer()
            Button { showDriveManager = true } label: {
                Label("Manage Drives", systemImage: "externaldrive.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.msSecondaryBackground)
    }

    private var previewNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundColor(.msAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("UI preview with sample data")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.msLabel)
                Text("Explore selection, drive, and approval flows. MacSweep will not scan, move, or delete anything.")
                    .font(.system(size: 11))
                    .foregroundColor(.msSecondaryLabel)
            }
            Spacer()
            Text("DEMO")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.msAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.msAccent.opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(Color.msAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.msAccent.opacity(0.2), lineWidth: 1))
    }

    private var storageOverview: some View {
        HStack(spacing: 12) {
            StorageMetricCard(title: "Developer files", value: ByteFormatter.format(tools.reduce(0) { $0 + $1.totalSize }), detail: "Across 4 developer tools", icon: "hammer.fill", tint: .msAccent)
            StorageMetricCard(title: "Safe to review", value: ByteFormatter.format(33_554_432_000), detail: "Caches and reproducible builds", icon: "checkmark.shield.fill", tint: .msSafe)
            StorageMetricCard(title: "Selected", value: ByteFormatter.format(selectedSize), detail: "\(selectedItems.count) categories in this plan", icon: "checkmark.circle.fill", tint: .msCaution)
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Storage destination", subtitle: "Choose where selected developer data should be managed")
            HStack(spacing: 12) {
                ForEach(destinations) { destination in
                    DestinationCard(destination: destination, isSelected: selectedDestinationID == destination.id) {
                        selectedDestinationID = destination.id
                    }
                }
            }
        }
    }

    private var toolSections: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Developer tools", subtitle: "Xcode is shown first, followed by other detected tool data")
            ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                DeveloperToolPreviewCard(tool: tool, position: index + 1, selectedItemIDs: $selectedItemIDs)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedItems.count) categories selected • \(ByteFormatter.format(selectedSize))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.msLabel)
                Text("Destination: \(selectedDestination.name)")
                    .font(.system(size: 11))
                    .foregroundColor(.msSecondaryLabel)
            }
            Spacer()
            Button("Clear Selection") { selectedItemIDs.removeAll() }
                .buttonStyle(.bordered)
                .disabled(selectedItemIDs.isEmpty)
            Button { showApproval = true } label: {
                Label("Review Plan", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedItemIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.msSecondaryBackground)
    }

    private var driveManagerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Manage Storage Destinations").font(.system(size: 18, weight: .bold))
                    Text("Sample drives for the UI prototype").font(.system(size: 12)).foregroundColor(.msSecondaryLabel)
                }
                Spacer()
                Button("Done") { showDriveManager = false }.keyboardShortcut(.cancelAction)
            }

            ForEach(destinations) { destination in
                HStack(spacing: 12) {
                    Image(systemName: destination.icon)
                        .font(.system(size: 22))
                        .foregroundColor(destination.isExternal ? .msAccent : .msSecondaryLabel)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(destination.name).font(.system(size: 13, weight: .semibold))
                            if destination.isExternal {
                                Text("EXTERNAL").font(.system(size: 8, weight: .bold)).foregroundColor(.msAccent)
                            }
                        }
                        Text("\(destination.detail) • \(destination.freeSpace) free")
                            .font(.system(size: 11)).foregroundColor(.msSecondaryLabel)
                    }
                    Spacer()
                    Button(selectedDestinationID == destination.id ? "Selected" : "Use Drive") {
                        selectedDestinationID = destination.id
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedDestinationID == destination.id)
                }
                .padding(12)
                .background(Color.msSecondaryBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").foregroundColor(.msAccent)
                Text("Connect another external drive").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("Coming with live storage support").font(.system(size: 10)).foregroundColor(.msSecondaryLabel)
            }
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(Color.msSeparator))
        }
        .padding(22)
        .frame(width: 540)
    }

    private var approvalSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 28)).foregroundColor(.msSafe)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Approve Storage Plan").font(.system(size: 18, weight: .bold))
                    Text("Review the sample operation before continuing").font(.system(size: 12)).foregroundColor(.msSecondaryLabel)
                }
            }

            VStack(spacing: 0) {
                ApprovalRow(label: "Selected data", value: "\(selectedItems.count) categories")
                Divider()
                ApprovalRow(label: "Estimated size", value: ByteFormatter.format(selectedSize))
                Divider()
                ApprovalRow(label: "Destination", value: selectedDestination.name)
                Divider()
                ApprovalRow(label: "Planned action", value: selectedDestination.isExternal ? "Move and keep projects linked" : "Review for cleanup")
            }
            .background(Color.msSecondaryBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Approval is required before any future live operation. This prototype does not access your files or drives.")
                .font(.system(size: 11)).foregroundColor(.msSecondaryLabel).fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel") { showApproval = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Approve Demo Plan") {
                    showApproval = false
                    showDemoConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 500)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.msLabel)
            Text(subtitle).font(.system(size: 11)).foregroundColor(.msSecondaryLabel)
        }
    }
}

private struct DeveloperStorageItem: Identifiable {
    let id: String
    let name: String
    let detail: String
    let size: Int64
    let isRecommended: Bool
}

private struct DeveloperToolPreview: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let tint: Color
    let items: [DeveloperStorageItem]

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

private struct DeveloperStorageDestination: Identifiable {
    let id: String
    let name: String
    let detail: String
    let freeSpace: String
    let icon: String
    let isExternal: Bool
}

private enum DeveloperStoragePreview {
    static let tools: [DeveloperToolPreview] = [
        DeveloperToolPreview(id: "xcode", name: "Xcode", subtitle: "Builds, simulators, archives, and device support", icon: "hammer.fill", tint: .blue, items: [
            DeveloperStorageItem(id: "xcode-derived-data", name: "Derived Data", detail: "Safe to rebuild after cleanup", size: 12_884_901_888, isRecommended: true),
            DeveloperStorageItem(id: "xcode-archives", name: "Archives", detail: "Keep builds needed for symbolication", size: 8_912_896_000, isRecommended: false),
            DeveloperStorageItem(id: "xcode-simulators", name: "Unused Simulators", detail: "Runtimes not used in 90 days", size: 15_247_523_840, isRecommended: true),
            DeveloperStorageItem(id: "xcode-device-support", name: "Device Support", detail: "Older iOS debugging symbols", size: 4_294_967_296, isRecommended: true)
        ]),
        DeveloperToolPreview(id: "node", name: "Node.js", subtitle: "Package caches and old project dependencies", icon: "shippingbox.fill", tint: .green, items: [
            DeveloperStorageItem(id: "node-modules", name: "Archived node_modules", detail: "Dependencies from inactive projects", size: 6_442_450_944, isRecommended: false),
            DeveloperStorageItem(id: "node-cache", name: "npm & Yarn caches", detail: "Downloaded packages can be restored", size: 2_147_483_648, isRecommended: true)
        ]),
        DeveloperToolPreview(id: "docker", name: "Docker", subtitle: "Unused images, build cache, and stopped containers", icon: "shippingbox.circle.fill", tint: .cyan, items: [
            DeveloperStorageItem(id: "docker-images", name: "Unused Images", detail: "Images not referenced by containers", size: 10_737_418_240, isRecommended: true),
            DeveloperStorageItem(id: "docker-cache", name: "Build Cache", detail: "Intermediate build layers", size: 5_368_709_120, isRecommended: true)
        ]),
        DeveloperToolPreview(id: "homebrew", name: "Homebrew & Gradle", subtitle: "Downloaded bottles and reproducible build caches", icon: "terminal.fill", tint: .orange, items: [
            DeveloperStorageItem(id: "homebrew-cache", name: "Homebrew Downloads", detail: "Previously downloaded formula packages", size: 3_221_225_472, isRecommended: true),
            DeveloperStorageItem(id: "gradle-cache", name: "Gradle Cache", detail: "Old dependency and build artifacts", size: 4_831_838_208, isRecommended: true)
        ])
    ]

    static let destinations: [DeveloperStorageDestination] = [
        DeveloperStorageDestination(id: "macintosh", name: "Macintosh HD", detail: "Internal • APFS", freeSpace: "118 GB", icon: "internaldrive.fill", isExternal: false),
        DeveloperStorageDestination(id: "external-t7", name: "Developer SSD", detail: "External • USB-C • APFS", freeSpace: "712 GB", icon: "externaldrive.fill", isExternal: true),
        DeveloperStorageDestination(id: "backup", name: "Archive Drive", detail: "External • Thunderbolt", freeSpace: "1.4 TB", icon: "externaldrive.fill.badge.timemachine", isExternal: true)
    ]
}

private struct StorageMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(.msSecondaryLabel)
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.msLabel)
                Text(detail).font(.system(size: 9)).foregroundColor(.msSecondaryLabel).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 12)
        .frame(maxWidth: .infinity)
    }
}

private struct DestinationCard: View {
    let destination: DeveloperStorageDestination
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: destination.icon).font(.system(size: 18)).foregroundColor(isSelected ? .msAccent : .msSecondaryLabel)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.name).font(.system(size: 12, weight: .semibold)).foregroundColor(.msLabel)
                    Text("\(destination.freeSpace) free").font(.system(size: 10)).foregroundColor(.msSecondaryLabel)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").foregroundColor(isSelected ? .msAccent : .msSecondaryLabel)
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(isSelected ? Color.msAccent.opacity(0.08) : Color.msSecondaryBackground))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(isSelected ? Color.msAccent : Color.primary.opacity(0.1), lineWidth: isSelected ? 1.5 : 0.5))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct DeveloperToolPreviewCard: View {
    let tool: DeveloperToolPreview
    let position: Int
    @Binding var selectedItemIDs: Set<String>

    private var selectedCount: Int { tool.items.filter { selectedItemIDs.contains($0.id) }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tool.tint.opacity(0.13)).frame(width: 42, height: 42)
                    Image(systemName: tool.icon).font(.system(size: 18, weight: .semibold)).foregroundColor(tool.tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(tool.name).font(.system(size: 14, weight: .bold)).foregroundColor(.msLabel)
                        if position == 1 {
                            Text("FIRST").font(.system(size: 8, weight: .bold)).foregroundColor(.blue)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.11), in: Capsule())
                        }
                    }
                    Text(tool.subtitle).font(.system(size: 11)).foregroundColor(.msSecondaryLabel)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormatter.format(tool.totalSize)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.msLabel)
                    Text("\(selectedCount) of \(tool.items.count) selected").font(.system(size: 10)).foregroundColor(.msSecondaryLabel)
                }
                Button(selectedCount == tool.items.count ? "Deselect" : "Select All") {
                    if selectedCount == tool.items.count {
                        tool.items.forEach { selectedItemIDs.remove($0.id) }
                    } else {
                        tool.items.forEach { selectedItemIDs.insert($0.id) }
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
            }
            .padding(14)
            Divider()

            ForEach(Array(tool.items.enumerated()), id: \.element.id) { index, item in
                Button {
                    if selectedItemIDs.contains(item.id) { selectedItemIDs.remove(item.id) } else { selectedItemIDs.insert(item.id) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                            .font(.system(size: 15)).foregroundColor(selectedItemIDs.contains(item.id) ? .msAccent : .msSecondaryLabel)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.name).font(.system(size: 12, weight: .semibold)).foregroundColor(.msLabel)
                                if item.isRecommended {
                                    Text("RECOMMENDED").font(.system(size: 8, weight: .bold)).foregroundColor(.msSafe)
                                }
                            }
                            Text(item.detail).font(.system(size: 10)).foregroundColor(.msSecondaryLabel)
                        }
                        Spacer()
                        Text(ByteFormatter.format(item.size)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.msLabel)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < tool.items.count - 1 { Divider().padding(.leading, 40) }
            }
        }
        .background(Color.msSecondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
    }
}

private struct ApprovalRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.msSecondaryLabel)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundColor(.msLabel)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
