import SwiftUI

struct SystemInfo {
    var cpuUsage: Double
    var ramUsage: Double
    var storageUsed: Int64
    var storageCapacity: Int64
    var temperature: Double
    var fanSpeed: Int
}

// MARK: - Safety Level
enum SafetyLevel {
    case safe
    case caution
    case unsafe
    
    var description: String {
        switch self {
        case .safe: return "Safe to delete"
        case .caution: return "May reset preferences"
        case .unsafe: return "Required by app"
        }
    }
}

// MARK: - Cleanable Items
struct CleanableItem: Identifiable {
    let id: UUID
    let category: CleanCategory
    let path: String
    let size: Int64
    let files: [CleanableFile]
    
    init(category: CleanCategory, path: String, size: Int64, files: [CleanableFile] = []) {
        self.id = UUID()
        self.category = category
        self.path = path
        self.size = size
        self.files = files
    }
    
    /// Dominant safety level for the category
    var dominantSafety: SafetyLevel {
        let safeCount = files.filter { $0.safetyLevel == .safe }.count
        let cautionCount = files.filter { $0.safetyLevel == .caution }.count
        let unsafeCount = files.filter { $0.safetyLevel == .unsafe }.count
        
        if unsafeCount > safeCount + cautionCount { return .unsafe }
        if cautionCount > safeCount { return .caution }
        return .safe
    }
}

struct CleanableFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let safetyLevel: SafetyLevel
}

enum CleanCategory: String, CaseIterable {
    case systemCache = "System Cache"
    case appCache = "App Cache"
    case logs = "Log Files"
    case xcodeDerived = "Xcode Derived Data"
    case browserData = "Browser Data"
    case downloads = "Old Downloads"
    case trash = "Trash"
    
    var icon: String {
        switch self {
        case .systemCache: return "gearshape.2.fill"
        case .appCache: return "app.fill"
        case .logs: return "doc.text.fill"
        case .xcodeDerived: return "hammer.fill"
        case .browserData: return "globe"
        case .downloads: return "arrow.down.circle.fill"
        case .trash: return "trash.fill"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .systemCache: return .blue
        case .appCache: return .orange
        case .logs: return .gray
        case .xcodeDerived: return .blue
        case .browserData: return .purple
        case .downloads: return .green
        case .trash: return .red
        }
    }
    
    var displayName: String { rawValue }
}

// MARK: - App Uninstaller
struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let iconPath: String?
    let bundleIdentifier: String?
}

enum AppFileType: String {
    case cache = "Cache"
    case preference = "Preferences"
    case support = "App Support"
    case log = "Logs"
    case savedState = "Saved State"
    case container = "Container"
    case plugin = "Plugin"
    case launcher = "Launch Agent"
    case groupContainer = "Group Container"
    
    var displayName: String { rawValue }
}

struct AppFileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let type: AppFileType
    let safetyLevel: SafetyLevel
}

struct AppProcessInfo: Identifiable {
    let id = UUID()
    let name: String
    let cpuUsage: Double
    let ramMB: Double
    let pid: Int32
}
