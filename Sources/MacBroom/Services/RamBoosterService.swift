import Foundation
import Darwin

// MARK: - Memory Info
struct MemoryInfo {
    let totalBytes: UInt64
    let freeBytes: UInt64
    let activeBytes: UInt64
    let inactiveBytes: UInt64    // Reclaimable
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let speculativeBytes: UInt64
    let purgeableBytes: UInt64   // Can be freed by OS
    let externalBytes: UInt64    // Memory-mapped from external sources
    let pressureLevel: MemoryPressureLevel
    
    /// Used memory = Total - Available (matches Activity Monitor exactly)
    /// Available = Free + Inactive + Speculative + Purgeable + External
    var usedBytes: UInt64 {
        let available = freeBytes + inactiveBytes + speculativeBytes + purgeableBytes + externalBytes
        return totalBytes > available ? totalBytes - available : 0
    }
    
    /// Available memory (matches macOS)
    var availableBytes: UInt64 {
        freeBytes + inactiveBytes + speculativeBytes + purgeableBytes + externalBytes
    }
    
    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    var freePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }
}

enum MemoryPressureLevel: Int {
    case normal = 1
    case warning = 2
    case critical = 3
    case urgent = 4
    
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Moderate"
        case .critical: return "High"
        case .urgent: return "Critical"
        }
    }
}

// MARK: - Process Info (single process from kernel)
struct RawProcessInfo {
    let pid: Int32
    let name: String
    let rss: UInt64          // Resident Set Size in bytes (from proc_pidinfo)
    let virtualSize: UInt64  // Virtual memory size
    let threads: Int32
    let path: String
}

// MARK: - App Info (grouped by app bundle)
struct AppMemoryInfo: Identifiable {
    let id = UUID()
    let name: String          // Clean app name
    let bundleID: String?     // Bundle identifier if available
    let totalRSS: UInt64      // Sum of all processes
    let processCount: Int     // Number of processes
    let icon: String          // SF Symbol name
    let processes: [RawProcessInfo]
    
    var rssString: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalRSS), countStyle: .memory)
    }
}

// MARK: - RamBoosterService
class RamBoosterService {
    
    /// Get current memory info using host_statistics64 (same as Activity Monitor)
    nonisolated static func getMemoryInfo() -> MemoryInfo {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        
        var hostInfo = vm_statistics64_data_t()
        var hostCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &hostCount)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return MemoryInfo(
                totalBytes: totalRAM, freeBytes: 0, activeBytes: 0,
                inactiveBytes: 0, wiredBytes: 0, compressedBytes: 0,
                speculativeBytes: 0, purgeableBytes: 0, externalBytes: 0,
                pressureLevel: .normal
            )
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(hostInfo.free_count) * pageSize
        let active = UInt64(hostInfo.active_count) * pageSize
        let inactive = UInt64(hostInfo.inactive_count) * pageSize
        let wired = UInt64(hostInfo.wire_count) * pageSize
        let compressed = UInt64(hostInfo.compressor_page_count) * pageSize
        let speculative = UInt64(hostInfo.speculative_count) * pageSize
        let purgeable = UInt64(hostInfo.purgeable_count) * pageSize
        let external = UInt64(hostInfo.external_page_count) * pageSize
        
        // Pressure level based on available memory (matches macOS)
        let availableRatio = Double(free + inactive + speculative + purgeable + external) / Double(totalRAM)
        let pressureLevel: MemoryPressureLevel
        switch availableRatio {
        case 0.30...1.0: pressureLevel = .normal
        case 0.15..<0.30: pressureLevel = .warning
        case 0.05..<0.15: pressureLevel = .critical
        default: pressureLevel = .urgent
        }
        
        return MemoryInfo(
            totalBytes: totalRAM,
            freeBytes: free,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            speculativeBytes: speculative,
            purgeableBytes: purgeable,
            externalBytes: external,
            pressureLevel: pressureLevel
        )
    }
    
    /// Free up RAM using malloc pressure trick
    nonisolated static func freeUpRAM() -> UInt64 {
        let before = getMemoryInfo().freeBytes
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        
        for _ in 1...3 {
            let allocSize = Int(Double(totalRAM) * 0.5)
            let ptr = UnsafeMutableRawPointer.allocate(byteCount: allocSize, alignment: 16)
            for i in stride(from: 0, to: allocSize, by: Int(vm_kernel_page_size)) {
                ptr.storeBytes(of: UInt8(1), toByteOffset: i, as: UInt8.self)
            }
            ptr.deallocate()
        }
        
        let after = getMemoryInfo().freeBytes
        return after > before ? (after - before) : 0
    }
    
    // MARK: - Process Listing (accurate: uses proc_pidinfo API)
    
    /// Get top apps by memory usage, grouped by app bundle
    nonisolated static func getTopApps(limit: Int = 10) -> [AppMemoryInfo] {
        let allProcesses = getAllProcesses()
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        
        // Group processes by app
        var appGroups: [String: [RawProcessInfo]] = [:]
        
        for proc in allProcesses {
            let appKey = resolveAppKey(for: proc)
            appGroups[appKey, default: []].append(proc)
        }
        
        // Build AppMemoryInfo
        var apps: [AppMemoryInfo] = []
        for (key, processes) in appGroups {
            let totalRSS = processes.reduce(UInt64(0)) { $0 + $1.rss }
            guard totalRSS > 5_000_000 else { continue } // Skip < 5MB
            
            let icon = resolveIcon(for: key)
            let displayName = resolveDisplayName(for: key)
            
            apps.append(AppMemoryInfo(
                name: displayName,
                bundleID: nil,
                totalRSS: totalRSS,
                processCount: processes.count,
                icon: icon,
                processes: processes.sorted { $0.rss > $1.rss }
            ))
        }
        
        // Sort by memory usage
        apps.sort { $0.totalRSS > $1.totalRSS }
        
        return Array(apps.prefix(limit))
    }
    
    /// Get all processes using proc_pidinfo (kernel API, same as Activity Monitor)
    nonisolated static func getAllProcesses() -> [RawProcessInfo] {
        let procType = UInt32(PROC_ALL_PIDS)
        var bufSize = proc_listpids(procType, 0, nil, 0)
        guard bufSize > 0 else { return [] }
        
        var pids = [Int32](repeating: 0, count: Int(bufSize) / MemoryLayout<Int32>.size)
        bufSize = proc_listpids(procType, 0, &pids, bufSize)
        let pidCount = Int(bufSize) / MemoryLayout<Int32>.size
        
        var processes: [RawProcessInfo] = []
        
        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }
            
            // Get task info (RSS, virtual size, threads)
            var taskInfo = proc_taskinfo()
            let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            guard taskResult > 0 else { continue }
            
            // Get process name and path
            var bsdInfo = proc_bsdinfo()
            let bsdResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
            
            let name: String
            if bsdResult > 0 {
                name = withUnsafePointer(to: bsdInfo.pbi_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) {
                        String(cString: $0)
                    }
                }
            } else {
                continue
            }
            
            // Get full path via proc_pidpath (works without sudo)
            var pathBuffer = [CChar](repeating: 0, count: 4096)
            let pathLen = proc_pidpath(pid, &pathBuffer, 4096)
            let path = pathLen > 0 ? String(cString: pathBuffer) : ""
            
            let rss = UInt64(taskInfo.pti_resident_size)
            let virtualSize = UInt64(taskInfo.pti_virtual_size)
            
            processes.append(RawProcessInfo(
                pid: pid,
                name: name,
                rss: rss,
                virtualSize: virtualSize,
                threads: taskInfo.pti_threadnum,
                path: path
            ))
        }
        
        return processes
    }
    
    // MARK: - App Resolution
    
    /// Group processes by app (e.g., all Firefox plugin-containers → "Firefox")
    nonisolated static func resolveAppKey(for process: RawProcessInfo) -> String {
        let path = process.path.lowercased()
        let name = process.name.lowercased()
        
        // 1. Extract from /Applications/SomeApp.app/...
        if let range = path.range(of: "/applications/") {
            let after = path[range.upperBound...]
            if let dotRange = after.range(of: ".app/") ?? after.range(of: ".app") {
                let appName = String(after[..<dotRange.lowerBound])
                // Map known app names to cleaner names
                if appName.contains("firefox") { return "Firefox" }
                if appName.contains("visual studio code") { return "VS Code" }
                if appName.contains("xcode") { return "Xcode" }
                return appName.capitalized
            }
        }
        
        // 2. DerivedData apps (development builds)
        if path.contains("/deriveddata/") {
            // Extract app name from the path
            if let lastComponent = process.path.components(separatedBy: "/").last {
                return lastComponent
            }
            return process.name
        }
        
        // 3. Homebrew
        if path.contains("/homebrew/") {
            if name == "node" { return "Node.js" }
            return process.name
        }
        
        // 4. System processes
        if path.contains("/system/library/") { return "macOS System" }
        if path.contains("/usr/libexec/") { return "macOS System" }
        if path.contains("/usr/sbin/") { return "macOS System" }
        if path.contains("/sbin/") { return "macOS System" }
        
        // 5. Known names
        if name == "windowserver" { return "WindowServer" }
        if name == "kernel" { return "Kernel" }
        if name == "launchd" { return "launchd" }
        if name == "loginwindow" { return "loginwindow" }
        if name == "finder" { return "Finder" }
        if name == "dock" { return "Dock" }
        
        // 6. OpenClaw
        if name.contains("openclaw") { return "OpenClaw" }
        
        // 7. Developer tools (from Xcode toolchain)
        if path.contains("toolchains/") || path.contains("/developer/") { return "Developer Tools" }
        
        return process.name
    }
    
    /// Get display-friendly app name
    nonisolated static func resolveDisplayName(for key: String) -> String {
        let displayNames: [String: String] = [
            "macos system": "macOS System",
            "developer tools": "Developer Tools",
            "vs code": "VS Code",
            "windowserver": "WindowServer",
            "plugin-container": "Firefox",
            "firefox gpu helper": "Firefox",
            "firefox": "Firefox",
        ]
        return displayNames[key.lowercased()] ?? key
    }
    
    /// Get SF Symbol icon for app
    nonisolated static func resolveIcon(for key: String) -> String {
        let icons: [String: String] = [
            "firefox": "globe",
            "safari": "safari",
            "chrome": "globe",
            "vs code": "chevron.left.forwardslash.chevron.right",
            "cursor": "chevron.left.forwardslash.chevron.right",
            "developer tools": "hammer.fill",
            "macos system": "gearshape.fill",
            "windowserver": "display",
            "finder": "folder.fill",
            "mail": "envelope.fill",
            "messages": "message.fill",
            "music": "music.note",
            "photos": "photo.fill",
            "calendar": "calendar",
            "notes": "note.text",
            "terminal": "terminal.fill",
            "xcode": "hammer.fill",
            "node.js": "cube.fill",
            "openclaw": "cpu",
            "docker": "cube.box.fill",
            "slack": "message.fill",
            "discord": "bubble.left.fill",
            "zoom.us": "video.fill",
            "spotify": "music.note",
            "figma": "paintbrush.fill",
            "android": "robot",
        ]
        return icons[key.lowercased()] ?? "app.fill"
    }
}
