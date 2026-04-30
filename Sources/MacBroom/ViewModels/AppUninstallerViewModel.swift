import Foundation

class AppUninstallerViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    
    func refreshApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = AppUninstallerService.shared.getInstalledApps()
            DispatchQueue.main.async {
                self?.apps = apps
                self?.isLoading = false
            }
        }
    }
    
    func deleteSelectedFiles(app: InstalledApp, fileIDs: Set<UUID>, files: [AppFileItem]) {
        let selected = files.filter { fileIDs.contains($0.id) }
        
        do {
            let deleted = try AppUninstallerService.shared.deleteFiles(selected)
            print("Deleted \(ByteCountFormatter.string(fromByteCount: deleted, countStyle: .file))")
            
            // Refresh app size
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                let updatedApp = InstalledApp(
                    name: app.name,
                    path: app.path,
                    size: AppUninstallerService.shared.getInstalledApps()
                        .first(where: { $0.bundleIdentifier == app.bundleIdentifier })?.size ?? app.size,
                    iconPath: app.iconPath,
                    bundleIdentifier: app.bundleIdentifier
                )
                apps[index] = updatedApp
            }
        } catch {
            print("Delete failed: \(error)")
        }
    }
    
    func uninstallApp(_ app: InstalledApp) {
        let relatedFiles = AppUninstallerService.shared.findRelatedFiles(for: app)
        
        do {
            try AppUninstallerService.shared.uninstallApp(app, relatedFiles: relatedFiles)
            apps.removeAll { $0.id == app.id }
        } catch {
            print("Uninstall failed: \(error)")
        }
    }
}
