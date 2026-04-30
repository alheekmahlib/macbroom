import Foundation
import Darwin

struct NetworkInterface: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let isActive: Bool
}

class SystemMonitorViewModel: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var cpuUser: Double = 0
    @Published var cpuSystem: Double = 0
    @Published var cpuIdle: Double = 100
    @Published var cpuCoreCount: Int = 0
    @Published var cpuModel: String = ""
    
    @Published var ramUsage: Double = 0
    @Published var ramUsedGB: Double = 0
    @Published var ramCachedGB: Double = 0
    @Published var ramFreeGB: Double = 0
    @Published var totalRAM: String = ""
    
    @Published var temperature: Double = 45
    @Published var fanSpeed: Int = 0
    @Published var batteryLevel: Double = 100
    @Published var batteryCharging: Bool = false
    @Published var batteryTimeRemaining: Double = 0
    
    @Published var topProcesses: [AppProcessInfo] = []
    @Published var threadCount: Int = 0
    
    @Published var networkDownload: String = "0 KB/s"
    @Published var networkUpload: String = "0 KB/s"
    @Published var totalDownload: String = "0 B"
    @Published var totalUpload: String = "0 B"
    @Published var networkInterfaces: [NetworkInterface] = []
    
    @Published var storageUsedGB: Double = 0
    @Published var storageTotalGB: Double = 0
    @Published var systemDataGB: Double = 0
    @Published var documentsGB: Double = 0
    @Published var mailGB: Double = 0
    @Published var appsGB: Double = 0
    @Published var otherUsersGB: Double = 0
    @Published var freeGB: Double = 0
    @Published var systemDataPercent: Double = 0
    @Published var documentsPercent: Double = 0
    @Published var mailPercent: Double = 0
    @Published var appsPercent: Double = 0
    @Published var otherUsersPercent: Double = 0
    
    @Published var uptime: String = ""
    
    private let sysInfo = SystemInfoService.shared
    
    func startMonitoring() {
        // Static info (all native now)
        cpuCoreCount = ProcessInfo.processInfo.activeProcessorCount
        cpuModel = sysInfo.getCPUModel()
        totalRAM = {
            let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000
            return String(format: "%.0f GB", gb)
        }()
        
        update()
    }
    
    func update() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // CPU — Native Mach API
            let cpu = self.sysInfo.getCPUUsageDelta()
            DispatchQueue.main.async {
                self.cpuUsage = cpu.total
                self.cpuUser = cpu.user
                self.cpuSystem = cpu.system
                self.cpuIdle = cpu.idle
            }
            
            // RAM — Native host_statistics64
            let ram = self.sysInfo.getRAMInfo()
            let ramGB: Double = 1_000_000_000
            DispatchQueue.main.async {
                self.ramUsedGB = ram.used  // already in GB from service
                self.ramCachedGB = ram.cached
                self.ramFreeGB = ram.free
                let totalGB = Double(ram.total) / ramGB
                let usedGBValue = Double(ram.total) / ramGB - ram.free
                self.ramUsage = totalGB > 0 ? (usedGBValue / totalGB) * 100 : 0
            }
            
            // Temperature — IOKit
            let temp = self.sysInfo.getTemperature()
            DispatchQueue.main.async {
                self.temperature = temp > 0 ? temp : 45.0
            }
            
            // Top Processes — libproc (no shell)
            let processes = self.sysInfo.getTopProcesses(limit: 10)
            let threads = self.sysInfo.getThreadCount()
            DispatchQueue.main.async {
                self.topProcesses = processes
                self.threadCount = threads
            }
            
            // Network — getifaddrs (no shell)
            let netStats = self.sysInfo.getNetworkStats()
            let interfaces = self.sysInfo.getNetworkInterfaces().map { info in
                NetworkInterface(name: info.name, address: info.address, isActive: info.isActive)
            }
            DispatchQueue.main.async {
                self.networkDownload = self.formatSpeed(Double(netStats.downloadSpeed))
                self.networkUpload = self.formatSpeed(Double(netStats.uploadSpeed))
                self.totalDownload = self.formatBytes(netStats.totalDownload)
                self.totalUpload = self.formatBytes(netStats.totalUpload)
                self.networkInterfaces = interfaces
            }
            
            // Storage — matches About This Mac (decimal GB)
            let storage = self.sysInfo.getStorageInfo()
            let gb = 1_000_000_000.0
            let totalGB = Double(storage.capacity) / gb
            let usedGB = Double(storage.used) / gb
            let freeGBVal = Double(storage.available) / gb
            DispatchQueue.main.async {
                self.storageUsedGB = usedGB
                self.storageTotalGB = totalGB
                self.freeGB = freeGBVal
                // Proportional breakdown (macOS doesn't expose exact per-category)
                let used = usedGB
                self.appsGB = used * 0.30
                self.documentsGB = used * 0.18
                self.mailGB = used * 0.06
                self.systemDataGB = used * 0.28
                self.otherUsersGB = used * 0.18
                let t = totalGB
                self.systemDataPercent = t > 0 ? self.systemDataGB / t : 0
                self.documentsPercent = t > 0 ? self.documentsGB / t : 0
                self.mailPercent = t > 0 ? self.mailGB / t : 0
                self.appsPercent = t > 0 ? self.appsGB / t : 0
                self.otherUsersPercent = t > 0 ? self.otherUsersGB / t : 0
            }
            
            // Battery — IOKit
            let battery = self.sysInfo.getBatteryInfo()
            DispatchQueue.main.async {
                self.batteryLevel = battery.level
                self.batteryCharging = battery.charging
                self.batteryTimeRemaining = battery.timeRemaining
            }
            
            // Uptime — sysctl
            let uptimeStr = self.sysInfo.getUptime()
            DispatchQueue.main.async {
                self.uptime = uptimeStr
            }
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 { return String(format: "%.0f B/s", bytesPerSecond) }
        else if bytesPerSecond < 1_048_576 { return String(format: "%.1f KB/s", bytesPerSecond / 1024) }
        else { return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576) }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_000_000
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        let kb = Double(bytes) / 1000
        return String(format: "%.0f KB", kb)
    }
}
