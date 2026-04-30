import SwiftUI
import Foundation

// MARK: - Disk Item
struct DiskItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    var size: Int64
    let isDirectory: Bool
    var children: [DiskItem]
    var isSizeLoaded: Bool
    
    init(id: UUID = UUID(), url: URL, name: String, size: Int64 = 0, isDirectory: Bool, children: [DiskItem] = [], isSizeLoaded: Bool = false) {
        self.id = id
        self.url = url
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
        self.isSizeLoaded = isSizeLoaded
    }
    
    static func == (lhs: DiskItem, rhs: DiskItem) -> Bool {
        lhs.id == rhs.id
    }
    
    var sizeString: String {
        guard isSizeLoaded else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var fileCount: Int {
        if !isDirectory { return 1 }
        return children.reduce(0) { $0 + $1.fileCount }
    }
}

// MARK: - Scan Result (cached tree)
struct ScanResult {
    var dirSizes: [String: Int64]        // path -> total size
    var dirChildren: [String: [String]]  // parent path -> child paths
    var dirFileCounts: [String: Int]     // path -> number of files
}

// MARK: - ViewModel
@MainActor
class DiskAnalyzerViewModel: ObservableObject {
    @Published var rootItems: [DiskItem] = []
    @Published var selectedItems: Set<UUID> = []
    @Published var isScanning = false
    @Published var currentScanPath = ""
    @Published var hasScanned = false
    @Published var totalUsedBytes: Int64 = 0
    @Published var totalCapacityBytes: Int64 = 0
    @Published var volumes: [DiskVolume] = []
    @Published var isLoadingSubfolder: UUID? = nil
    @Published var scanProgress: Double = 0  // 0.0 - 1.0 — real progress from scan
    @Published var filesScanned: Int = 0
    @Published var estimatedTotalFiles: Int = 0  // estimated total for progress calc
    
    private var allItemsFlat: [UUID: DiskItem] = [:]
    private var scanTask: Task<Void, Never>?
    
    // Cached scan result — the full tree from one-pass scan
    private var scanResult: ScanResult?
    private var scannedRootPath: String?
    
    // MARK: - System Skip Lists
    
    /// Root-level directories to skip entirely (system)
    nonisolated private static let skipRoot = Set([
        "System", "usr", "bin", "sbin", "var", "private", "tmp", "etc",
        "dev", "Volumes", "opt", "cores", "Network", "automount", ".vol"
    ])
    
    /// Library subdirectories to skip (system/ephemeral)
    nonisolated private static let skipLibrary = Set([
        "Caches", "Logs", "Saved Application State", "HTTPStorages",
        "Cookies", "Preferences", "WebKit", "Safari", "SafariSafeBrowsing",
        "Application Scripts", "Assistant", "Assistants", "Biome",
        "CallServices", "ColorPickers", "Colors", "Compositions",
        "ContainerManager", "Containers", "Group Containers",
        "DoNotDisturb", "DuetExpertCenter", "Favorites", "FontCollections",
        "Fonts", "FrontBoard", "GameKit", "HomeKit", "IdentityServices",
        "Input Methods", "IntelligencePlatform", "Intents", "Internet Plug-Ins",
        "Keyboard Layouts", "KeyboardServices", "LanguageModeling",
        "LaunchAgents", "LockdownMode", "PPM", "Passes",
        "PersonalizationPortrait", "PreferencePanes", "Printers",
        "PrivateCloudCompute", "Reminders", "ResponseKit",
        "Screen Savers", "Services", "Sharing", "Shortcuts", "Sounds",
        "Spelling", "Spotlight", "StatusKit", "Suggestions",
        "Translation", "Trial", "UnifiedAssetFramework", "Weather",
        "Daemon Containers", "com.apple.AppleMediaServices",
        "com.apple.aiml.instrumentation", "com.apple.appleaccountd",
        "com.apple.bluetooth.services.cloud", "com.apple.bluetoothuser",
        "com.apple.iTunesCloud", "com.apple.internal.ck",
        "homeenergyd", "iTunes", "org.swift.swiftpm", "studentd"
    ])
    
    /// Developer subdirectories to skip (Xcode simulators, etc)
    nonisolated private static let skipDeveloper = Set([
        "CoreSimulator", "Xcode", "UserData"
    ])
    
    // MARK: - Computed Properties
    
    var totalSelectedSize: Int64 {
        selectedItems.compactMap { allItemsFlat[$0]?.size }.reduce(0, +)
    }
    
    var totalSelectedSizeString: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }
    
    var usedPercent: Double {
        guard totalCapacityBytes > 0 else { return 0 }
        return Double(totalUsedBytes) / Double(totalCapacityBytes)
    }
    
    // MARK: - Load Volumes
    func loadVolumes() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let vols = Self.detectVolumes()
            DispatchQueue.main.async {
                self?.volumes = vols
            }
        }
    }
    
    private nonisolated static func detectVolumes() -> [DiskVolume] {
        var volumes: [DiskVolume] = []
        let fm = FileManager.default
        let volumeKeys: [URLResourceKey] = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeNameKey
        ]
        
        let rootURL = URL(fileURLWithPath: "/")
        if let values = try? rootURL.resourceValues(forKeys: Set(volumeKeys)) {
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let name = values.volumeName ?? "Macintosh HD"
            volumes.append(DiskVolume(
                name: name, path: "/",
                totalBytes: total, usedBytes: total - available, availableBytes: available,
                isStartupDisk: true, icon: "internaldrive.fill"
            ))
        }
        
        if let volumeContents = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for volName in volumeContents {
                guard volName != "Macintosh HD" else { continue }
                let volPath = "/Volumes/" + volName
                let volURL = URL(fileURLWithPath: volPath)
                if let values = try? volURL.resourceValues(forKeys: Set(volumeKeys)) {
                    let total = Int64(values.volumeTotalCapacity ?? 0)
                    guard total > 0 else { continue }
                    let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
                    volumes.append(DiskVolume(
                        name: volName, path: volPath,
                        totalBytes: total, usedBytes: total - available, availableBytes: available,
                        isStartupDisk: false, icon: "externaldrive.fill"
                    ))
                }
            }
        }
        return volumes
    }
    
    // MARK: - One-Pass Deep Scan (DaisyDisk approach)
    
    func startScan(path: String, completion: @escaping (Bool) -> Void) {
        scanTask?.cancel()
        scannedRootPath = path
        
        scanTask = Task { [weak self] in
            guard let self = self else { return }
            
            self.isScanning = true
            self.rootItems = []
            self.selectedItems = []
            self.allItemsFlat = [:]
            self.totalUsedBytes = 0
            self.scanProgress = 0
            self.filesScanned = 0
            self.estimatedTotalFiles = 0
            self.currentScanPath = "Preparing..."
            
            // Estimate total files based on used space (rough: ~5000 files per GB for user data)
            let url = URL(fileURLWithPath: path)
            if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
                self.totalCapacityBytes = Int64(values.volumeTotalCapacity ?? 0)
                let usedGB = Double(self.totalCapacityBytes) / 1_073_741_824.0
                // Rough estimate: user data has ~3000-8000 files per GB
                // For home dir scan (~80GB used): estimate ~100K files
                self.estimatedTotalFiles = max(50_000, Int(usedGB * 5000))
            }
            
            // Run the one-pass deep scan on background thread
            let result = await self.performDeepScan(rootPath: path)
            
            guard !Task.isCancelled else {
                self.isScanning = false
                completion(false)
                return
            }
            
            // Cache the full result
            self.scanResult = result
            
            // Build root items from cached result
            let items = self.buildItemsFromCache(parentPath: path, result: result)
            
            self.rootItems = items
            self.totalUsedBytes = items.reduce(Int64(0)) { $0 + $1.size }
            self.flattenAllItems()
            self.isScanning = false
            self.scanProgress = 1.0
            self.hasScanned = true
            
            completion(!items.isEmpty)
        }
    }
    
    func startScan() {
        startScan(path: "/") { _ in }
    }
    
    /// One-pass deep scan — builds complete tree of all sizes
    private func performDeepScan(rootPath: String) async -> ScanResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: ScanResult(dirSizes: [:], dirChildren: [:], dirFileCounts: [:]))
                    return
                }
                
                let fm = FileManager.default
                var dirSizes: [String: Int64] = [:]
                var dirChildren: [String: [String]] = [:]
                var dirFileCounts: [String: Int] = [:]
                var fileCount = 0
                
                let rootURL = URL(fileURLWithPath: rootPath)
                
                if let enumerator = fm.enumerator(
                    at: rootURL,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                    options: []
                ) {
                    while let fileURL = enumerator.nextObject() as? URL {
                        guard !Task.isCancelled else { break }
                        
                        let name = fileURL.lastPathComponent
                        let parent = fileURL.deletingLastPathComponent().path
                        
                        // Skip hidden files/dirs
                        if name.hasPrefix(".") {
                            if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                                enumerator.skipDescendants()
                            }
                            continue
                        }
                        
                        // Skip root-level system dirs
                        if parent == "/" && Self.skipRoot.contains(name) {
                            enumerator.skipDescendants()
                            continue
                        }
                        
                        // Skip Library system dirs
                        if parent.hasSuffix("/Library") && Self.skipLibrary.contains(name) {
                            enumerator.skipDescendants()
                            continue
                        }
                        
                        // Skip Developer system dirs
                        if parent.hasSuffix("/Developer") && Self.skipDeveloper.contains(name) {
                            enumerator.skipDescendants()
                            continue
                        }
                        
                        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { continue }
                        let isDir = values.isDirectory ?? false
                        
                        if isDir {
                            dirChildren[parent, default: []].append(fileURL.path)
                            dirFileCounts[fileURL.path] = 0
                        } else {
                            let size = Int64(values.fileSize ?? 0)
                            fileCount += 1
                            
                            // Update real progress periodically
                            if fileCount % 2000 == 0 {
                                let path = fileURL.deletingLastPathComponent().path
                                DispatchQueue.main.async {
                                    self.filesScanned = fileCount
                                    self.currentScanPath = path
                                    // Real progress: files scanned / estimated total
                                    // Cap at 0.92 so final jump to 1.0 is visible
                                    if self.estimatedTotalFiles > 0 {
                                        let rawProgress = Double(fileCount) / Double(self.estimatedTotalFiles)
                                        self.scanProgress = min(rawProgress * 0.92, 0.92)
                                    }
                                }
                            }
                            
                            // Accumulate size to all parent dirs
                            var path = fileURL.deletingLastPathComponent().path
                            let rootPathStr = rootPath
                            while true {
                                dirSizes[path, default: 0] += size
                                dirFileCounts[path, default: 0] += 1
                                if path == rootPathStr { break }
                                let p = URL(fileURLWithPath: path).deletingLastPathComponent().path
                                if !p.hasPrefix(rootPathStr) { break }
                                path = p
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.filesScanned = fileCount
                }
                
                continuation.resume(returning: ScanResult(dirSizes: dirSizes, dirChildren: dirChildren, dirFileCounts: dirFileCounts))
            }
        }
    }
    
    /// Build DiskItems from cached scan result (instant!)
    private func buildItemsFromCache(parentPath: String, result: ScanResult) -> [DiskItem] {
        let fm = FileManager.default
        let childPaths = result.dirChildren[parentPath] ?? []
        
        var items: [DiskItem] = []
        
        for childPath in childPaths {
            let name = URL(fileURLWithPath: childPath).lastPathComponent
            
            // Skip hidden (already filtered in scan, but just in case)
            if name.hasPrefix(".") { continue }
            
            var isDir: ObjCBool = false
            fm.fileExists(atPath: childPath, isDirectory: &isDir)
            let url = URL(fileURLWithPath: childPath)
            
            if isDir.boolValue {
                let size = result.dirSizes[childPath] ?? 0
                let children = buildItemsFromCache(parentPath: childPath, result: result)
                items.append(DiskItem(
                    url: url, name: name, size: size,
                    isDirectory: true, children: children,
                    isSizeLoaded: true  // Size is known from scan!
                ))
            } else {
                let size = result.dirSizes[childPath] ?? Int64((try? fm.attributesOfItem(atPath: childPath))?[.size] as? UInt ?? 0)
                items.append(DiskItem(
                    url: url, name: name, size: size,
                    isDirectory: false, children: [],
                    isSizeLoaded: true
                ))
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - Instant Navigation (uses cached result!)
    
    func loadChildren(for parentPath: String) -> [DiskItem] {
        guard let result = scanResult else { return [] }
        return buildItemsFromCache(parentPath: parentPath, result: result)
    }
    
    // MARK: - Subfolder Loading (for navigation — instant with cache)
    func loadSubfoldersAsync(for item: DiskItem, completion: @escaping ([DiskItem]) -> Void) {
        guard item.isDirectory else { completion([]); return }
        
        // If we have cached scan result, return instantly!
        if let result = scanResult {
            let children = buildItemsFromCache(parentPath: item.url.path, result: result)
            completion(children)
            return
        }
        
        // Fallback: no cache, list instantly and load sizes progressively
        isLoadingSubfolder = item.id
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let instantItems = self.listItemsInstantly(path: item.url.path)
            
            DispatchQueue.main.async {
                self.isLoadingSubfolder = nil
                completion(instantItems)
            }
        }
    }
    
    /// Instant listing without sizes (fallback only)
    nonisolated private func listItemsInstantly(path: String) -> [DiskItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        
        var items: [DiskItem] = []
        for name in contents {
            if name.hasPrefix(".") { continue }
            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            let url = URL(fileURLWithPath: fullPath)
            
            if isDir.boolValue {
                items.append(DiskItem(url: url, name: name, size: 0, isDirectory: true, children: [], isSizeLoaded: false))
            } else {
                let fileSize = Int64((try? fm.attributesOfItem(atPath: fullPath))?[.size] as? UInt ?? 0)
                if fileSize > 0 {
                    items.append(DiskItem(url: url, name: name, size: fileSize, isDirectory: false, children: [], isSizeLoaded: true))
                }
            }
        }
        return items
    }
    
    // MARK: - Flatten
    func flattenAllItems() {
        allItemsFlat = [:]
        for item in rootItems {
            flattenItem(item)
        }
        // Also flatten any items in navigation display
        // This ensures selected items in subdirectories are found
    }
    
    /// Flatten a specific list of items and their children into allItemsFlat
    func flattenItems(_ items: [DiskItem]) {
        for item in items {
            flattenItem(item)
        }
    }
    
    private func flattenItem(_ item: DiskItem) {
        allItemsFlat[item.id] = item
        for child in item.children {
            flattenItem(child)
        }
    }
    
    // MARK: - Selection
    func toggleSelect(_ item: DiskItem) {
        if selectedItems.contains(item.id) {
            removeSelection(item)
        } else {
            addSelection(item)
        }
    }
    
    func addSelection(_ item: DiskItem) {
        selectedItems.insert(item.id)
        if item.isDirectory {
            for child in item.children { addSelection(child) }
        }
    }
    
    func removeSelection(_ item: DiskItem) {
        selectedItems.remove(item.id)
        if item.isDirectory {
            for child in item.children { removeSelection(child) }
        }
    }
    
    func selectAll() {
        selectedItems = Set(allItemsFlat.keys)
    }
    
    func deselectAll() {
        selectedItems = []
    }
    
    // MARK: - Delete
    func deleteSelected() -> (deleted: Int, failed: Int, freedBytes: Int64) {
        var deleted = 0, failed = 0, freed: Int64 = 0
        
        let topLevelIDs = selectedItems.filter { id in
            guard let item = allItemsFlat[id] else { return false }
            return !hasSelectedParent(item)
        }
        
        for id in topLevelIDs {
            guard let item = allItemsFlat[id] else { continue }
            do {
                freed += item.size
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                deleted += 1
            } catch {
                failed += 1
            }
        }
        
        selectedItems = []
        return (deleted, failed, freed)
    }
    
    private func hasSelectedParent(_ item: DiskItem) -> Bool {
        let itemPath = item.url.path
        for selectedID in selectedItems {
            guard let parent = allItemsFlat[selectedID] else { continue }
            let parentPath = parent.url.path
            if itemPath.hasPrefix(parentPath) && itemPath != parentPath {
                return true
            }
        }
        return false
    }
}
