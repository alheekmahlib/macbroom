import SwiftUI
import Foundation

// MARK: - File Category
enum FileCategory: String, CaseIterable {
    case all = "All Files"
    case videos = "Videos"
    case audios = "Audio"
    case images = "Images"
    case documents = "Documents"
    case archives = "Archives"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .all: return "folder.fill"
        case .videos: return "film.fill"
        case .audios: return "music.note"
        case .images: return "photo.fill"
        case .documents: return "doc.fill"
        case .archives: return "doc.zipper"
        case .other: return "questionmark.folder.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return MacBroomTheme.accent
        case .videos: return .purple
        case .audios: return .pink
        case .images: return MacBroomTheme.success
        case .documents: return MacBroomTheme.warning
        case .archives: return .yellow
        case .other: return MacBroomTheme.textMuted
        }
    }
    
    var extensions: Set<String> {
        switch self {
        case .all: return []
        case .videos: return ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp", "ts"]
        case .audios: return ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff", "alac", "opus"]
        case .images: return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif", "svg", "ico", "raw", "cr2", "nef"]
        case .documents: return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "pages", "numbers", "keynote", "md"]
        case .archives: return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg"]
        case .other: return []
        }
    }
}

// MARK: - Found File
struct FoundFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let modifiedDate: Date
    let category: FileCategory
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var ext: String {
        url.pathExtension.lowercased()
    }
    
    var icon: String {
        switch category {
        case .videos: return "film.fill"
        case .audios: return "music.note"
        case .images: return "photo.fill"
        case .documents: return "doc.fill"
        case .archives: return "doc.zipper"
        case .other: return "doc.questionmark.fill"
        case .all: return "doc.fill"
        }
    }
}

// MARK: - ViewModel
@MainActor
class LargeFilesViewModel: ObservableObject {
    @Published var allFiles: [FoundFile] = []
    @Published var selectedCategory: FileCategory = .all
    @Published var selectedFiles: Set<UUID> = []
    @Published var isScanning = false
    @Published var scanProgress: CGFloat = 0
    @Published var currentScanPath = ""
    @Published var minimumSizeMB: Int = 100
    @Published var hasScanned = false
    
    // Scan state
    private var scanTask: Task<Void, Never>?
    
    // MARK: - Computed
    var filteredFiles: [FoundFile] {
        switch selectedCategory {
        case .all: return allFiles
        case .other:
            let known = FileCategory.videos.extensions
                .union(FileCategory.audios.extensions)
                .union(FileCategory.images.extensions)
                .union(FileCategory.documents.extensions)
                .union(FileCategory.archives.extensions)
            return allFiles.filter { !known.contains($0.ext) || $0.ext.isEmpty }
        default:
            return allFiles.filter { selectedCategory.extensions.contains($0.ext) }
        }
    }
    
    var categoryCounts: [(FileCategory, Int, Int64)] {
        FileCategory.allCases.map { cat in
            let files: [FoundFile]
            if cat == .all { files = allFiles }
            else if cat == .other {
                let known = FileCategory.videos.extensions
                    .union(FileCategory.audios.extensions)
                    .union(FileCategory.images.extensions)
                    .union(FileCategory.documents.extensions)
                    .union(FileCategory.archives.extensions)
                files = allFiles.filter { !known.contains($0.ext) || $0.ext.isEmpty }
            } else {
                files = allFiles.filter { cat.extensions.contains($0.ext) }
            }
            return (cat, files.count, files.reduce(Int64(0)) { $0 + $1.size })
        }
    }
    
    var totalSelectedSize: Int64 {
        allFiles.filter { selectedFiles.contains($0.id) }.reduce(Int64(0)) { $0 + $1.size }
    }
    
    var totalSelectedSizeString: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }
    
    // MARK: - Directories to scan
    private nonisolated var scanDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            home + "/Documents",
            home + "/Downloads",
            home + "/Desktop",
            home + "/Movies",
            home + "/Music",
            home + "/Pictures",
            home + "/Library/Application Support",
            "/Applications"
        ]
    }
    
    // MARK: - Scan
    func startScan() {
        // Cancel any existing scan
        scanTask?.cancel()
        
        scanTask = Task { [weak self] in
            guard let self = self else { return }
            
            self.isScanning = true
            self.scanProgress = 0
            self.allFiles = []
            self.selectedFiles = []
            self.currentScanPath = "Searching files..."
            
            let minBytes = Int64(self.minimumSizeMB) * 1_048_576
            let dirs = self.scanDirectories
            
            // Run find with live output reading
            let results: [FoundFile] = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.runFindCommandLive(
                        minBytes: minBytes,
                        directories: dirs,
                        onProgress: { path, fileCount in
                            DispatchQueue.main.async {
                                self.currentScanPath = path
                                self.scanProgress = min(0.95, CGFloat(fileCount) / 100.0 * 0.5)
                            }
                        },
                        completion: { files in
                            continuation.resume(returning: files)
                        }
                    )
                }
            }
            
            // Check cancellation
            guard !Task.isCancelled else {
                self.isScanning = false
                return
            }
            
            self.allFiles = results
            self.isScanning = false
            self.scanProgress = 1.0
            self.hasScanned = true
            
            // Reset progress after animation
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.scanProgress = 0
        }
    }
    
    /// Runs `find` command with live progress reporting. Called on background thread.
    private nonisolated func runFindCommandLive(
        minBytes: Int64,
        directories: [String],
        onProgress: @escaping (String, Int) -> Void,
        completion: @escaping ([FoundFile]) -> Void
    ) {
        let minMB = Int(minBytes / 1_048_576)
        
        let excludes = [
            "*/.*", "*/node_modules/*", "*/.Trash/*",
            "*/Library/Developer/*", "*/Library/Mail/*",
            "*/Library/Caches/*", "*/.gradle/*",
            "*/.cargo/*", "*/.rustup/*", "*/.npm/*", "*/.m2/*"
        ]
        
        var args = [String]()
        for dir in directories {
            if FileManager.default.fileExists(atPath: dir) {
                args.append(dir)
            }
        }
        args += ["-type", "f", "-size", "+\(minMB)M"]
        for exc in excludes { args += ["-not", "-path", exc] }
        args.append("-print0")
        
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do { try process.run() } catch { completion([]); return }
        
        let handle = pipe.fileHandleForReading
        var allData = Data()
        var fileCount = 0
        var lastProgressTime = CFAbsoluteTimeGetCurrent()
        
        // Read output as it comes (non-blocking)
        while process.isRunning {
            let chunk = handle.availableData
            if !chunk.isEmpty {
                allData.append(chunk)
                // Count new null-delimited entries
                let newNulls = chunk.filter { $0 == 0 }.count
                fileCount += newNulls
                
                // Report progress (throttled to every 0.2s)
                let now = CFAbsoluteTimeGetCurrent()
                if newNulls > 0 && now - lastProgressTime > 0.2 {
                    lastProgressTime = now
                    // Find last complete path for display
                    if let lastNull = allData.lastIndex(of: 0) {
                        let searchStart = allData.startIndex
                        let prevNull = allData[searchStart..<lastNull].lastIndex(of: 0) ?? searchStart
                        let lastPathData = allData[prevNull..<lastNull]
                        let lastPath = String(data: lastPathData.filter { $0 != 0 }, encoding: .utf8) ?? ""
                        onProgress(lastPath, fileCount)
                    }
                }
            }
            usleep(50000) // 50ms sleep to avoid busy-waiting
        }
        
        // Read any remaining data
        let remaining = handle.readDataToEndOfFile()
        allData.append(remaining)
        process.waitUntilExit()
        
        // Parse all paths
        let paths = allData.split(separator: 0).compactMap { String(data: $0, encoding: .utf8) }
        
        // Get file attributes
        let fm = FileManager.default
        var found: [FoundFile] = []
        found.reserveCapacity(paths.count)
        
        for (i, path) in paths.enumerated() {
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let size = attrs[.size] as? Int64,
                  size >= minBytes
            else { continue }
            
            let url = URL(fileURLWithPath: path)
            let ext = url.pathExtension.lowercased()
            
            found.append(FoundFile(
                url: url,
                name: url.lastPathComponent,
                size: size,
                modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                category: categorize(ext: ext)
            ))
            
            // Report attribute-reading progress (0.5 to 0.95)
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastProgressTime > 0.15 {
                lastProgressTime = now
                onProgress(url.lastPathComponent, paths.count + i)
            }
        }
        
        found.sort { $0.size > $1.size }
        completion(found)
    }
    
    private nonisolated func categorize(ext: String) -> FileCategory {
        if FileCategory.videos.extensions.contains(ext) { return .videos }
        if FileCategory.audios.extensions.contains(ext) { return .audios }
        if FileCategory.images.extensions.contains(ext) { return .images }
        if FileCategory.documents.extensions.contains(ext) { return .documents }
        if FileCategory.archives.extensions.contains(ext) { return .archives }
        return .other
    }
    
    // MARK: - Selection
    func toggleFile(_ id: UUID) {
        if selectedFiles.contains(id) { selectedFiles.remove(id) }
        else { selectedFiles.insert(id) }
    }
    
    func selectAll() { selectedFiles = Set(filteredFiles.map { $0.id }) }
    func deselectAll() { selectedFiles = [] }
    
    // MARK: - Delete
    func deleteSelected() -> (deleted: Int, failed: Int, freedBytes: Int64) {
        var deleted = 0, failed = 0, freed: Int64 = 0
        for fileId in selectedFiles {
            guard let file = allFiles.first(where: { $0.id == fileId }) else { continue }
            do {
                freed += file.size
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                deleted += 1
            } catch { failed += 1 }
        }
        allFiles.removeAll { selectedFiles.contains($0.id) }
        selectedFiles = []
        return (deleted, failed, freed)
    }
}
