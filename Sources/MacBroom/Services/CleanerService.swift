import Foundation

class CleanerService {
    static let shared = CleanerService()
    
    private let maxFilesPerCategory = 100
    
    private init() {}
    
    // MARK: - Default scan targets (NO browser data)
    private let defaultScanTargets: [(CleanCategory, String)] = [
        (.systemCache, "~/Library/Caches"),
        (.appCache, "~/Library/Application Support"),
        (.logs, "~/Library/Logs"),
        (.xcodeDerived, "~/Library/Developer/Xcode/DerivedData"),
        (.trash, "~/.Trash"),
    ]
    
    private let browserScanTargets: [(CleanCategory, String)] = [
        (.browserData, "~/Library/Safari"),
        (.browserData, "~/Library/Caches/Google"),
        (.browserData, "~/Library/Caches/Firefox"),
    ]
    
    // MARK: - Scan
    func scan(includeBrowserData: Bool = false, progress: @escaping (String) -> Void, completion: @escaping ([CleanableItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var results: [CleanableItem] = []
            
            var targets = self.defaultScanTargets
            if includeBrowserData {
                targets.append(contentsOf: self.browserScanTargets)
            }
            
            for (category, rawPath) in targets {
                let path = NSString(string: rawPath).expandingTildeInPath
                progress(path)
                
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                
                // Trash: special handling — show as single item
                if category == .trash {
                    let totalSize = self.calculateDirSize(at: path)
                    if totalSize > 0 {
                        let itemCount = (try? fm.contentsOfDirectory(atPath: path).count) ?? 0
                        let file = CleanableFile(
                            name: "Trash Items",
                            path: path,
                            size: totalSize,
                            safetyLevel: .safe
                        )
                        results.append(CleanableItem(
                            category: .trash,
                            path: path,
                            size: totalSize,
                            files: [file]
                        ))
                    }
                    continue
                }
                
                let files = self.scanDirectory(at: path, category: category)
                let totalSize = files.reduce(Int64(0)) { $0 + $1.size }
                
                if !files.isEmpty {
                    results.append(CleanableItem(
                        category: category,
                        path: path,
                        size: totalSize,
                        files: files
                    ))
                }
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
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
                size = calculateDirSize(at: itemPath)
            } else {
                size = (try? fm.attributesOfItem(atPath: itemPath)[.size] as? Int64) ?? 0
            }
            
            guard size > 100_000 else { continue } // > 100KB
            
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
    
    // MARK: - Safety
    private func determineSafety(path: String, category: CleanCategory) -> SafetyLevel {
        let filename = (path as NSString).lastPathComponent.lowercased()
        
        if filename.contains("keychain") { return .unsafe }
        if filename.hasPrefix("com.apple.shared") || filename.hasPrefix("com.apple.login") { return .unsafe }
        
        if category == .systemCache {
            if filename.hasPrefix("com.apple.") { return .caution }
            return .safe
        }
        if category == .logs { return .safe }
        if category == .xcodeDerived { return .safe }
        if category == .trash { return .safe }
        if category == .browserData { return .caution }
        if category == .appCache { return .caution }
        
        return .safe
    }
    
    // MARK: - Size calculation
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
    
    // MARK: - Clean (simple)
    func cleanFiles(fileIDs: Set<UUID>, from results: [CleanableItem], completion: @escaping (Result<Int64, Error>) -> Void) {
        cleanFilesProgressive(fileIDs: fileIDs, from: results, onProgress: { _, _ in }, completion: completion)
    }
    
    // MARK: - Clean with progressive updates
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
                    sizeBefore = self.calculateDirSize(at: file.path)
                } else {
                    sizeBefore = (try? fm.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? file.size
                }
                
                // Try trashItem first, fallback to removeItem
                do {
                    let url = URL(fileURLWithPath: file.path)
                    
                // Trash category: permanently delete contents (not the Trash folder itself)
                    // Everything else: use trashItem (move to trash)
                    if category == .trash {
                        // Delete contents of Trash, not the .Trash folder
                        guard let trashContents = try? fm.contentsOfDirectory(atPath: file.path) else {
                            print("⚠️ Could not read trash contents")
                            continue
                        }
                        var trashCleaned: Int64 = 0
                        for trashItem in trashContents {
                            let trashItemPath = (file.path as NSString).appendingPathComponent(trashItem)
                            do {
                                try fm.removeItem(atPath: trashItemPath)
                                let itemSize = self.calculateSizeQuick(at: trashItemPath, originalSize: 0)
                                trashCleaned += itemSize
                            } catch {
                                print("⚠️ Could not delete \(trashItem): \(error.localizedDescription)")
                            }
                        }
                        totalCleaned += max(sizeBefore, trashCleaned)
                        print("🗑 Emptied \(trashContents.count) trash items")
                    } else {
                        // First attempt: trash
                        var trashResult: NSURL?
                        do {
                            try fm.trashItem(at: url, resultingItemURL: &trashResult)
                            print("✅ Trashed: \(file.name) (\(ByteCountFormatter.string(fromByteCount: sizeBefore, countStyle: .file)))")
                        } catch {
                            // trashItem failed — try removeItem directly
                            print("⚠️ trashItem failed for \(file.name): \(error.localizedDescription)")
                            print("   Trying removeItem...")
                            
                            try fm.removeItem(at: url)
                            print("✅ Removed: \(file.name)")
                        }
                    }
                    
                    // For directories: do NOT recreate — user chose to delete it
                    
                    totalCleaned += sizeBefore
                    
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
    
    private func calculateSizeQuick(at path: String, originalSize: Int64) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: path, isDirectory: &isDir) {
            return isDir.boolValue ? calculateDirSize(at: path) : ((try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? originalSize)
        }
        return originalSize
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
        return calculateDirSize(at: trashPath)
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
                    print("🗑 Emptied: \(item) (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))")
                } catch {
                    print("⚠️ Failed to empty \(item): \(error.localizedDescription)")
                }
                
                cleaned += 1
                progress(cleaned, total)
            }
            
            print("🗑 Trash emptied: \(ByteCountFormatter.string(fromByteCount: totalCleaned, countStyle: .file))")
            
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
            return calculateDirSize(at: path)
        } else {
            return (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        }
    }
}
