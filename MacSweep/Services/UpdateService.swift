import Foundation
import Combine
import Sparkle

/// Securely checks, downloads, verifies, and installs application updates.
@MainActor
public final class UpdateService: ObservableObject {
    private let controller: SPUStandardUpdaterController
    public let isConfigured: Bool

    public init() {
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let configured = !(publicKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        isConfigured = configured
        controller = SPUStandardUpdaterController(
            startingUpdater: configured,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    public var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    public var automaticallyDownloadsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    public var canCheckForUpdates: Bool {
        isConfigured && controller.updater.canCheckForUpdates
    }

    public func checkForUpdates() {
        guard isConfigured else { return }
        controller.checkForUpdates(nil)
    }
}
