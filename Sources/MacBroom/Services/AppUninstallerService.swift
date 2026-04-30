import Foundation

class AppUninstallerService {
    static let shared = AppUninstallerService()
    
    private init() {}
    
    // MARK: - Get Installed Apps
    func getInstalledApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fm = FileManager.default
        
        let appDirs = [
            "/Applications",
            NSString(string: "~/Applications").expandingTildeInPath,
            "/System/Applications"
        ]
        
        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents where item.hasSuffix(".app") {
                let appPath = (dir as NSString).appendingPathComponent(item)
                let name = item.replacingOccurrences(of: ".app", with: "")
                let size = calculateDirSize(at: appPath)
                let bundleID = Bundle(path: appPath)?.bundleIdentifier
                
                apps.append(InstalledApp(
                    name: name,
                    path: appPath,
                    size: size,
                    iconPath: appPath,
                    bundleIdentifier: bundleID
                ))
            }
        }
        
        return apps.sorted { $0.size > $1.size }
    }
    
    // MARK: - Find Related Files (top-level items only, with safety)
    func findRelatedFilesDetailed(for app: InstalledApp) -> [AppFileItem] {
        var items: [AppFileItem] = []
        let fm = FileManager.default
        let home = NSString(string: "~").expandingTildeInPath
        let library = (home as NSString).appendingPathComponent("Library")
        
        let bundleID: String = app.bundleIdentifier ?? app.name.lowercased().replacingOccurrences(of: " ", with: "-")
        let appName = app.name
        
        let searchLocations: [(String, AppFileType)] = [
            ((library as NSString).appendingPathComponent("Caches"), .cache),
            ((library as NSString).appendingPathComponent("Preferences"), .preference),
            ((library as NSString).appendingPathComponent("Application Support"), .support),
            ((library as NSString).appendingPathComponent("Logs"), .log),
            ((library as NSString).appendingPathComponent("Saved Application State"), .savedState),
            ((library as NSString).appendingPathComponent("Containers"), .container),
            ((library as NSString).appendingPathComponent("Group Containers"), .groupContainer),
            ((library as NSString).appendingPathComponent("LaunchAgents"), .launcher),
        ]
        
        for (dir, type) in searchLocations {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents {
                let matches = item.localizedCaseInsensitiveContains(bundleID) ||
                    item.localizedCaseInsensitiveContains(appName) ||
                    item.localizedCaseInsensitiveContains(appName.replacingOccurrences(of: " ", with: ""))
                
                guard matches else { continue }
                
                let fullPath = (dir as NSString).appendingPathComponent(item)
                let size = calculateSize(at: fullPath)
                
                guard size > 0 else { continue }
                
                let safety = determineAppFileSafety(type: type)
                
                items.append(AppFileItem(
                    name: item,
                    path: fullPath,
                    size: size,
                    type: type,
                    safetyLevel: safety
                ))
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    func findRelatedFiles(for app: InstalledApp) -> [String] {
        return findRelatedFilesDetailed(for: app).map(\.path)
    }
    
    // MARK: - Safety
    private func determineAppFileSafety(type: AppFileType) -> SafetyLevel {
        switch type {
        case .cache:      return .safe
        case .log:        return .safe
        case .savedState: return .safe
        case .preference: return .caution
        case .support:    return .caution
        case .container:  return .caution
        case .groupContainer: return .unsafe
        case .launcher:   return .caution
        case .plugin:     return .caution
        }
    }
    
    // MARK: - Delete specific files
    func deleteFiles(_ fileItems: [AppFileItem]) throws -> Int64 {
        let fm = FileManager.default
        var totalDeleted: Int64 = 0
        
        for file in fileItems {
            guard file.safetyLevel != .unsafe else { continue }
            
            if fm.fileExists(atPath: file.path) {
                do {
                    try fm.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                    totalDeleted += file.size
                } catch {
                    // Try admin delete
                    try? deleteWithAdmin(path: file.path)
                    totalDeleted += file.size
                }
            }
        }
        
        return totalDeleted
    }
    
    // MARK: - Uninstall whole app
    func uninstallApp(_ app: InstalledApp, relatedFiles: [String]) throws {
        let fm = FileManager.default
        
        // Try trashItem first
        do {
            var resultURL: NSURL?
            try fm.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: &resultURL)
        } catch {
            // Permission denied — try with admin privileges via AppleScript
            try deleteWithAdmin(path: app.path)
        }
        
        // Clean related files
        for file in relatedFiles {
            if fm.fileExists(atPath: file) {
                try? fm.trashItem(at: URL(fileURLWithPath: file), resultingItemURL: nil)
            }
        }
    }
    
    // MARK: - Delete with admin privileges
    private func deleteWithAdmin(path: String) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "do shell script \"rm -rf '\(path)'\" with administrator privileges"
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "MacBroom", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Failed to delete: \(errorMsg)"])
        }
    }
    
    // MARK: - Size calculations (depth-limited)
    private func calculateDirSize(at path: String) -> Int64 {
        let fm = FileManager.default
        var totalSize: Int64 = 0
        var count = 0
        
        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
        
        for case let file as String in enumerator {
            count += 1
            if count > 50_000 { break }
            
            let filePath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: filePath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    private func calculateSize(at path: String) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        fm.fileExists(atPath: path, isDirectory: &isDir)
        
        if isDir.boolValue {
            return calculateDirSize(at: path)
        } else {
            return (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        }
    }
}
