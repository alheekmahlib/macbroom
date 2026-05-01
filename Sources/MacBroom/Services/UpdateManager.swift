import Foundation
import Sparkle

/// Manages app updates using Sparkle framework
final class UpdateManager: NSObject, ObservableObject {
    
    static let shared = UpdateManager()
    
    private let updaterController: SPUStandardUpdaterController
    let updater: SPUUpdater
    
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    
    /// Set to true when Sparkle is about to install an update.
    /// AppDelegate checks this to allow actual termination during updates.
    static var isInstallingUpdate = false
    
    private override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updater = updaterController.updater
        super.init()
        
        canCheckForUpdates = updater.canCheckForUpdates
    }
    
    /// Check for updates manually (shows UI if update available)
    func checkForUpdates() {
        updater.checkForUpdates()
    }
    
    /// The feed URL — must match your appcast.xml location
    /// Set this in Info.plist as SUFeedURL or programmatically
    func setFeedURL(_ url: URL) {
        updater.setFeedURL(url)
    }
}

// MARK: - SPUUpdaterDelegate (Sparkle 2)
extension UpdateManager: SPUUpdaterDelegate {
    
    /// Called when Sparkle wants to install an update on quit.
    /// We set the flag so AppDelegate allows actual termination.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock: @escaping () -> Void) {
        Self.isInstallingUpdate = true
        immediateInstallationBlock()
    }
    
    /// Called right before Sparkle installs the update
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        Self.isInstallingUpdate = true
    }
}

// MARK: - App Version Info
struct AppVersion {
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    static var fullVersion: String {
        "\(current) (\(buildNumber))"
    }
}
