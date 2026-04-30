import Foundation
import Sparkle

/// Manages app updates using Sparkle framework
final class UpdateManager: NSObject, ObservableObject {
    
    static let shared = UpdateManager()
    
    private let updaterController: SPUStandardUpdaterController
    private let updater: SPUUpdater
    
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    
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
