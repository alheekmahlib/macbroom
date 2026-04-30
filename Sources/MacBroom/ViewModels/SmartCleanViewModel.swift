import Foundation

class SmartCleanViewModel: ObservableObject {
    @Published var scanResults: [CleanableItem] = []
    @Published var selectedFileIDs: Set<UUID> = []
    @Published var isScanning = false
    @Published var currentScanPath = ""
    @Published var cleanedBytes: Int64 = 0
    
    // MARK: - Grouped results
    var safeItems: [CleanableItem] {
        scanResults.filter { $0.dominantSafety == .safe }
    }
    
    var cautionItems: [CleanableItem] {
        scanResults.filter { $0.dominantSafety == .caution }
    }
    
    var unsafeItems: [CleanableItem] {
        scanResults.filter { $0.dominantSafety == .unsafe }
    }
    
    var totalCleanableBytes: Int64 {
        var total: Int64 = 0
        for item in scanResults {
            for file in item.files where selectedFileIDs.contains(file.id) {
                total += file.size
            }
        }
        return total
    }
    
    // MARK: - Scan with callback
    func startScan(includeBrowserData: Bool = false, completion: @escaping (Bool) -> Void) {
        isScanning = true
        scanResults = []
        selectedFileIDs = []
        
        CleanerService.shared.scan(
            includeBrowserData: includeBrowserData,
            progress: { [weak self] path in
                DispatchQueue.main.async {
                    self?.currentScanPath = path
                }
            },
            completion: { [weak self] results in
                self?.isScanning = false
                self?.scanResults = results
                
                // Auto-select safe files
                var safeIDs: Set<UUID> = []
                for item in results where item.dominantSafety == .safe {
                    for file in item.files where file.safetyLevel == .safe {
                        safeIDs.insert(file.id)
                    }
                }
                self?.selectedFileIDs = safeIDs
                
                completion(!results.isEmpty)
            }
        )
    }
    
    // MARK: - Toggle
    func toggleFile(_ fileID: UUID, inCategory categoryID: UUID) {
        if selectedFileIDs.contains(fileID) {
            selectedFileIDs.remove(fileID)
        } else {
            selectedFileIDs.insert(fileID)
        }
    }
    
    func selectCategory(_ categoryID: UUID) {
        guard let item = scanResults.first(where: { $0.id == categoryID }) else { return }
        for file in item.files where file.safetyLevel != .unsafe {
            selectedFileIDs.insert(file.id)
        }
    }
    
    func deselectCategory(_ categoryID: UUID) {
        guard let item = scanResults.first(where: { $0.id == categoryID }) else { return }
        for file in item.files {
            selectedFileIDs.remove(file.id)
        }
    }
    
    func selectAllSafe() {
        var ids: Set<UUID> = []
        for item in scanResults {
            for file in item.files where file.safetyLevel == .safe {
                ids.insert(file.id)
            }
        }
        selectedFileIDs = ids
    }
    
    func deselectAll() {
        selectedFileIDs = []
    }
    
    // MARK: - Clean with progressive callback
    func cleanSelectedWithProgress(
        onProgress: @escaping (CGFloat, Int64) -> Void,
        completion: @escaping (Int64) -> Void
    ) {
        var selectedFiles: [(UUID, Int64)] = []
        for item in scanResults {
            for file in item.files where selectedFileIDs.contains(file.id) {
                selectedFiles.append((file.id, file.size))
            }
        }
        
        let total = selectedFiles.count
        guard total > 0 else {
            completion(0)
            return
        }
        
        CleanerService.shared.cleanFilesProgressive(
            fileIDs: selectedFileIDs,
            from: scanResults,
            onProgress: { cleaned, totalToClean in
                let progress = totalToClean > 0 ? CGFloat(cleaned) / CGFloat(totalToClean) : 0
                // Estimate bytes cleaned so far
                var bytesSoFar: Int64 = 0
                var count = 0
                for (fileID, fileSize) in selectedFiles {
                    if count >= Int(cleaned) { break }
                    bytesSoFar += fileSize
                    count += 1
                }
                DispatchQueue.main.async {
                    onProgress(progress, bytesSoFar)
                }
            },
            completion: { [weak self] result in
                switch result {
                case .success(let totalCleaned):
                    self?.scanResults = []
                    self?.selectedFileIDs = []
                    completion(totalCleaned)
                case .failure:
                    completion(0)
                }
            }
        )
    }
}
