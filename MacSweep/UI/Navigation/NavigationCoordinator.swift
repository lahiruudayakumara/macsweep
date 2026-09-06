import SwiftUI
import Combine

@MainActor
public final class NavigationCoordinator: ObservableObject {
    @Published public var selectedItem: NavigationItem? = .dashboard
    @Published public var showOnboarding: Bool = false
    private var hasPendingSmartScan = false
    private var hasPendingFullScan = false

    public init(selectedItem: NavigationItem? = .dashboard) {
        self.selectedItem = selectedItem
    }

    public func navigate(to item: NavigationItem) {
        self.selectedItem = item
    }

    /// Opens Smart Scan and asks that screen to immediately begin a new full scan.
    public func startSmartScan() {
        hasPendingSmartScan = true
        selectedItem = .smartScan
    }

    /// Opens the dedicated Full Scan screen and immediately starts a scan.
    public func startFullScan() {
        hasPendingFullScan = true
        selectedItem = .fullScan
    }

    /// Consumes a Dashboard scan request exactly once when Smart Scan appears.
    public func consumeSmartScanRequest() -> Bool {
        guard hasPendingSmartScan else { return false }
        hasPendingSmartScan = false
        return true
    }

    public func consumeFullScanRequest() -> Bool {
        guard hasPendingFullScan else { return false }
        hasPendingFullScan = false
        return true
    }
}
