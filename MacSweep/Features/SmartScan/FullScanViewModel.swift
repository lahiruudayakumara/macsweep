import SwiftUI
import Combine

@MainActor
public final class FullScanViewModel: ObservableObject {
    @Published public private(set) var isScanning = false
    @Published public private(set) var isPaused = false
    @Published public private(set) var isCleaning = false
    @Published public private(set) var currentProgress: ScanProgress?
    @Published public private(set) var scanResult: ScanResult?
    @Published public var items: [CleanupItem] = []
    @Published public private(set) var lastCleanResult: CleanResult?

    private let environment: AppEnvironment
    private var scanControl: ScanControl?
    private var scanTask: Task<ScanResult, Never>?
    private var activeScanID: UUID?

    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.size } }
    public var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    public var selectedCount: Int { items.filter(\.isSelected).count }

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func startScan() async {
        guard !isScanning else { return }
        let scanID = UUID()
        let control = ScanControl()
        activeScanID = scanID
        scanControl = control
        isScanning = true
        isPaused = false
        currentProgress = ScanProgress(totalCategoriesCount: 8)
        scanResult = nil
        items = []
        lastCleanResult = nil

        let startedAt = Date()
        let task = Task { [environment, weak self] in
            await environment.scanEngine.performFullScan(control: control) { progress in
                Task { @MainActor in
                    guard self?.activeScanID == scanID else { return }
                    self?.currentProgress = progress
                }
            }
        }
        scanTask = task
        let result = await task.value
        guard activeScanID == scanID, !control.isCancelled else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 2.5 {
            try? await Task.sleep(nanoseconds: UInt64((2.5 - elapsed) * 1_000_000_000))
        }
        guard activeScanID == scanID, !control.isCancelled else { return }

        scanResult = result
        items = result.items.map { item in
            var item = item
            item.isSelected = item.risk == .safe
            return item
        }
        isScanning = false
        isPaused = false
        scanTask = nil
        scanControl = nil
        activeScanID = nil
    }

    public func togglePause() {
        guard isScanning, let scanControl else { return }
        if isPaused {
            scanControl.resume()
        } else {
            scanControl.pause()
        }
        isPaused.toggle()
    }

    public func stopScan() {
        guard isScanning else { return }
        scanControl?.cancel()
        scanTask?.cancel()
        scanTask = nil
        scanControl = nil
        activeScanID = nil
        isPaused = false
        isScanning = false
        currentProgress = nil
        scanResult = nil
        items = []
    }

    public func selectSafeOnly() {
        for index in items.indices {
            items[index].isSelected = items[index].risk == .safe
        }
    }

    public func selectAll() {
        for index in items.indices { items[index].isSelected = true }
    }

    public func deselectAll() {
        for index in items.indices { items[index].isSelected = false }
    }

    public func toggle(_ item: CleanupItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isSelected.toggle()
    }

    public func setSelection(for category: CleanupCategory, isSelected: Bool) {
        for index in items.indices where items[index].category == category {
            items[index].isSelected = isSelected
        }
    }

    public func cleanSelected() async {
        guard !isCleaning, selectedCount > 0 else { return }
        isCleaning = true
        let result = await environment.cleanEngine.clean(items: items.filter(\.isSelected))
        lastCleanResult = result
        items.removeAll { item in
            item.isSelected && !result.failures.contains(where: { $0.url == item.url })
        }
        isCleaning = false
    }
}
