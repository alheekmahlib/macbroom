import Foundation

class CleanerService {
    static let shared = CleanerService()
    
    private let maxFilesPerCategory = 100
    
    private init() {}
    
    // MARK: - Scan Targets (based on technical report + safe paths)
    
    private let defaultScanTargets: [(CleanCategory, String)] = [
        // Caches — safe to delete (apps recreate them)
        (.systemCache, "~/Library/Caches"),
        
        // Logs — safe to delete, grow over time
        (.logs, "~/Library/Logs"),
        (.logs, "/Library/Logs"),
        
        // Xcode — biggest junk for developers
        (.xcodeDerived, "~/Library/Developer/Xcode/DerivedData"),
        
        // Mail Downloads — attachments previewed but forgotten
        (.mailDownloads, "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
        
        // Trash
        (.trash, "~/.Trash"),
    ]
    
    private let browserCacheTargets: [(CleanCategory, String)] = [
        // Safari
        (.browserCache, "~/Library/Caches/com.apple.Safari"),
        (.browserCache, "~/Library/Safari/LocalStorage"),
        
        // Chrome
        (.browserCache, "~/Library/Caches/Google/Chrome"),
        (.browserCache, "~/Library/Application Support/Google/Chrome/Default/Cache"),
        
        // Firefox
        (.browserCache, "~/Library/Caches/Firefox"),
        (.browserCache, "~/Library/Application Support/Firefox/Profiles"),
        
        // Edge
        (.browserCache, "~/Library/Caches/Microsoft Edge"),
    ]
    
    // MARK: - Scan
    
    func scan(includeBrowserData: Bool = false, progress: @escaping (String) -> Void, completion: @escaping ([CleanableItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [CleanableItem] = []
            
            var targets = self.defaultScanTargets
            if includeBrowserData {
                targets.append(contentsOf: self.browserCacheTargets)
            }
            
            for (category, rawPath) in targets {
                let path = NSString(string: rawPath).expandingTildeInPath
                progress(path)
                
                let item = self.scanTarget(path: path, category: category)
                if let item = item {
                    results.append(item)
                }
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
    
    // MARK: - Scan Single Target
    
    private func scanTarget(path: String, category: CleanCategory) -> CleanableItem? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
        
        // Trash: special handling — show as single item
        if category == .trash {
            let totalSize = calculateAllocatedSize(at: path)
            guard totalSize > 0 else { return nil }
            
            let file = CleanableFile(
                name: "Trash Items",
                path: path,
                size: totalSize,
                safetyLevel: .safe
            )
            return CleanableItem(category: .trash, path: path, size: totalSize, files: [file])
        }
        
        let files = scanDirectory(at: path, category: category)
        guard !files.isEmpty else { return nil }
        
        let totalSize = files.reduce(Int64(0)) { $0 + $1.size }
        return CleanableItem(category: category, path: path, size: totalSize, files: files)
    }
    
    // MARK: - Scan Directory
    
    private func scanDirectory(at path: String, category: CleanCategory) -> [CleanableFile] {
        let fm = FileManager.default
        var files: [CleanableFile] = []
        
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return files }
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            
            var isDir: ObjCBool = false
            fm.fileExists(atPath: itemPath, isDirectory: &isDir)
            
            let size: Int64
            if isDir.boolValue {
                size = calculateAllocatedSize(at: itemPath)
            } else {
                size = getFileAllocatedSize(at: itemPath)
            }
            
            guard size > 100_000 else { continue } // > 100KB threshold
            
            let safety = determineSafety(path: itemPath, category: category)
            
            files.append(CleanableFile(
                name: item,
                path: itemPath,
                size: size,
                safetyLevel: safety
            ))
            
            if files.count >= maxFilesPerCategory { break }
        }
        
        return files.sorted { $0.size > $1.size }
    }
    
    // MARK: - Safety Rules
    
    private func determineSafety(path: String, category: CleanCategory) -> SafetyLevel {
        let filename = (path as NSString).lastPathComponent.lowercased()
        
        // Never delete these — critical system files
        if filename.contains("keychain") { return .unsafe }
        if filename.hasPrefix("com.apple.shared") || filename.hasPrefix("com.apple.login") { return .unsafe }
        if filename.contains("security") { return .unsafe }
        
        // Category-specific rules
        switch category {
        case .systemCache:
            // Apple caches may cause temporary issues but are safe
            if filename.hasPrefix("com.apple.") { return .caution }
            return .safe
            
        case .logs:
            return .safe
            
        case .xcodeDerived:
            return .safe // Xcode regenerates these
            
        case .browserCache:
            // Cache files = safe, profile data = caution
            if filename.contains("bookmarks") || filename.contains("passwords") || filename.contains("cookies") {
                return .unsafe
            }
            if filename.hasSuffix(".sqlite") || filename.hasSuffix(".sqlite-wal") {
                return .caution // May lose session data
            }
            return .safe
            
        case .mailDownloads:
            return .safe // These are already-saved attachments
            
        case .trash:
            return .safe
            
        case .appCache:
            if filename.hasPrefix("com.apple.") { return .caution }
            return .safe
            
        case .downloads:
            return .caution // User's files — always confirm
        }
    }
    
    // MARK: - Size Calculation (Report Recommendation: allocatedSize)
    
    /// Calculate directory size using allocated (physical) size on disk
    /// This matches Finder more accurately than logical size
    private func calculateAllocatedSize(at path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        
        // Try allocatedSizeOfDirectory (macOS 10.11+)
        // This gives the actual physical disk usage (handles compression, sparse files)
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .isDirectoryKey
        ], options: [.skipsHiddenFiles], errorHandler: nil) {
            var totalSize: Int64 = 0
            var count = 0
            
            for case let fileURL as URL in enumerator {
                count += 1
                if count > 50_000 { break }
                
                if let values = try? fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey]) {
                    if values.isDirectory != true {
                        totalSize += Int64(values.fileAllocatedSize ?? values.totalFileAllocatedSize ?? 0)
                    }
                }
            }
            
            if totalSize > 0 {
                return totalSize
            }
        }
        
        // Fallback: FileManager attributes (logical size)
        return calculateDirSizeFallback(at: path)
    }
    
    /// Get allocated size for a single file
    private func getFileAllocatedSize(at path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.fileAllocatedSizeKey, .totalFileAllocatedSizeKey]) {
            return Int64(values.fileAllocatedSize ?? values.totalFileAllocatedSize ?? 0)
        }
        // Fallback
        return (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    }
    
    /// Fallback: use FileManager enumerator with .size attribute
    private func calculateDirSizeFallback(at path: String) -> Int64 {
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
    
    // MARK: - Clean (simple)
    
    func cleanFiles(fileIDs: Set<UUID>, from results: [CleanableItem], completion: @escaping (Result<Int64, Error>) -> Void) {
        cleanFilesProgressive(fileIDs: fileIDs, from: results, onProgress: { _, _ in }, completion: completion)
    }
    
    // MARK: - Clean with Progressive Updates
    
    func cleanFilesProgressive(
        fileIDs: Set<UUID>,
        from results: [CleanableItem],
        onProgress: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<Int64, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var totalCleaned: Int64 = 0
            var errors: [String] = []
            
            var selectedFiles: [(file: CleanableFile, category: CleanCategory)] = []
            for item in results {
                for file in item.files where fileIDs.contains(file.id) {
                    selectedFiles.append((file, item.category))
                }
            }
            
            let total = selectedFiles.count
            guard total > 0 else {
                DispatchQueue.main.async { completion(.success(0)) }
                return
            }
            
            var cleaned = 0
            
            for (file, category) in selectedFiles {
                defer {
                    cleaned += 1
                    onProgress(cleaned, total)
                }
                
                guard file.safetyLevel != .unsafe else { continue }
                
                var isDir: ObjCBool = false
                let exists = fm.fileExists(atPath: file.path, isDirectory: &isDir)
                
                guard exists else {
                    print("⚠️ File not found: \(file.path)")
                    continue
                }
                
                let sizeBefore: Int64
                if isDir.boolValue {
                    sizeBefore = self.calculateAllocatedSize(at: file.path)
                } else {
                    sizeBefore = self.getFileAllocatedSize(at: file.path)
                }
                
                do {
                    let url = URL(fileURLWithPath: file.path)
                    
                    if category == .trash {
                        // Trash: permanently delete contents (not the .Trash folder itself)
                        guard let trashContents = try? fm.contentsOfDirectory(atPath: file.path) else {
                            print("⚠️ Could not read trash contents")
                            continue
                        }
                        for trashItem in trashContents {
                            let trashItemPath = (file.path as NSString).appendingPathComponent(trashItem)
                            do {
                                try fm.removeItem(atPath: trashItemPath)
                            } catch {
                                print("⚠️ Could not delete \(trashItem): \(error.localizedDescription)")
                            }
                        }
                        totalCleaned += sizeBefore
                        print("🗑 Emptied \(trashContents.count) trash items")
                    } else {
                        // Report recommendation: use trashItem first (gives user undo chance)
                        var trashResult: NSURL?
                        do {
                            try fm.trashItem(at: url, resultingItemURL: &trashResult)
                            print("✅ Trashed: \(file.name) (\(ByteCountFormatter.string(fromByteCount: sizeBefore, countStyle: .file)))")
                        } catch {
                            // trashItem failed (e.g., cross-volume) — try removeItem
                            try fm.removeItem(at: url)
                            print("✅ Removed: \(file.name)")
                        }
                        totalCleaned += sizeBefore
                    }
                } catch {
                    let msg = "❌ Failed to delete \(file.name): \(error.localizedDescription)"
                    print(msg)
                    errors.append(msg)
                }
            }
            
            print("🧹 Clean complete: \(ByteCountFormatter.string(fromByteCount: totalCleaned, countStyle: .file)) cleaned, \(errors.count) errors")
            
            DispatchQueue.main.async {
                if totalCleaned > 0 {
                    completion(.success(totalCleaned))
                } else if !errors.isEmpty {
                    completion(.failure(CleanError.deleteFailed(errors.joined(separator: "\n"))))
                } else {
                    completion(.success(0))
                }
            }
        }
    }
}

// MARK: - Errors

enum CleanError: LocalizedError {
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .deleteFailed(let msg): return msg
        }
    }
}

// MARK: - Trash Service

extension CleanerService {
    
    func getTrashSize() -> Int64 {
        let trashPath = NSString(string: "~/.Trash").expandingTildeInPath
        return calculateAllocatedSize(at: trashPath)
    }
    
    func emptyTrash(progress: @escaping (Int, Int) -> Void, completion: @escaping (Result<Int64, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let trashPath = NSString(string: "~/.Trash").expandingTildeInPath
            var totalCleaned: Int64 = 0
            
            guard let contents = try? fm.contentsOfDirectory(atPath: trashPath) else {
                DispatchQueue.main.async { completion(.success(0)) }
                return
            }
            
            let total = contents.count
            var cleaned = 0
            
            for item in contents {
                let itemPath = (trashPath as NSString).appendingPathComponent(item)
                let size = self.calculateSize(at: itemPath)
                
                do {
                    try fm.removeItem(atPath: itemPath)
                    totalCleaned += size
                } catch {
                    print("⚠️ Failed to empty \(item): \(error.localizedDescription)")
                }
                
                cleaned += 1
                progress(cleaned, total)
            }
            
            DispatchQueue.main.async {
                completion(.success(totalCleaned))
            }
        }
    }
    
    private func calculateSize(at path: String) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        fm.fileExists(atPath: path, isDirectory: &isDir)
        
        if isDir.boolValue {
            return calculateAllocatedSize(at: path)
        } else {
            return getFileAllocatedSize(at: path)
        }
    }
}
