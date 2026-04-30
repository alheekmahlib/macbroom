import Foundation

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
    
    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    private var lastUpdateTime: Date = Date()
    
    func startMonitoring() {
        // Static info
        cpuCoreCount = ProcessInfo.processInfo.activeProcessorCount
        cpuModel = getCPUModel()
        totalRAM = getTotalRAM()
        
        update()
    }
    
    func update() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // System info
            SystemInfoService.shared.updateSystemInfo { result in
                DispatchQueue.main.async {
                    if case .success(let info) = result {
                        self.cpuUsage = info.cpuUsage * 100
                        self.ramUsage = info.ramUsage * 100
                        self.temperature = info.temperature
                    }
                }
            }
            
            // Detailed CPU
            let cpuDetail = self.getCPUDetail()
            DispatchQueue.main.async {
                self.cpuUser = cpuDetail.user
                self.cpuSystem = cpuDetail.system
                self.cpuIdle = cpuDetail.idle
            }
            
            // Detailed RAM
            let ramDetail = self.getRAMDetail()
            DispatchQueue.main.async {
                self.ramUsedGB = ramDetail.usedGB
                self.ramCachedGB = ramDetail.cachedGB
                self.ramFreeGB = ramDetail.freeGB
            }
            
            // Top processes
            let processes = SystemInfoService.shared.getTopProcesses(limit: 10)
            let threads = self.getThreadCount()
            DispatchQueue.main.async {
                self.topProcesses = processes
                self.threadCount = threads
            }
            
            // Network
            let netInfo = self.getNetworkInfo()
            let interfaces = self.getNetworkInterfaces()
            DispatchQueue.main.async {
                self.networkDownload = netInfo.download
                self.networkUpload = netInfo.upload
                self.networkInterfaces = interfaces
            }
            
            // Storage detail
            let storage = self.getStorageDetail()
            DispatchQueue.main.async {
                self.storageUsedGB = storage.usedGB
                self.storageTotalGB = storage.totalGB
                self.systemDataGB = storage.systemDataGB
                self.documentsGB = storage.documentsGB
                self.mailGB = storage.mailGB
                self.appsGB = storage.appsGB
                self.otherUsersGB = storage.otherUsersGB
                self.freeGB = storage.freeGB
                let t = storage.totalGB
                self.systemDataPercent = t > 0 ? storage.systemDataGB / t : 0
                self.documentsPercent = t > 0 ? storage.documentsGB / t : 0
                self.mailPercent = t > 0 ? storage.mailGB / t : 0
                self.appsPercent = t > 0 ? storage.appsGB / t : 0
                self.otherUsersPercent = t > 0 ? storage.otherUsersGB / t : 0
            }
            
            // Battery
            let battery = self.getBatteryInfo()
            DispatchQueue.main.async {
                self.batteryLevel = battery.level
                self.batteryCharging = battery.charging
                self.batteryTimeRemaining = battery.timeRemaining
            }
            
            // Uptime
            let uptimeStr = self.getUptime()
            DispatchQueue.main.async {
                self.uptime = uptimeStr
            }
        }
    }
    
    // MARK: - CPU Detail
    private func getCPUDetail() -> (user: Double, system: Double, idle: Double) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-n", "0", "-s", "0"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return (0, 0, 100) }
            
            if let range = output.range(of: "CPU usage:") {
                let substring = output[range.lowerBound...]
                let pattern = "([0-9]+\\.[0-9]+)% user.*?([0-9]+\\.[0-9]+)% sys.*?([0-9]+\\.[0-9]+)% idle"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: String(substring), range: NSRange(substring.startIndex..., in: substring)) {
                    let userStr = String(substring[Range(match.range(at: 1), in: substring)!])
                    let sysStr = String(substring[Range(match.range(at: 2), in: substring)!])
                    let idleStr = String(substring[Range(match.range(at: 3), in: substring)!])
                    return (Double(userStr) ?? 0, Double(sysStr) ?? 0, Double(idleStr) ?? 100)
                }
            }
        } catch {}
        return (0, 0, 100)
    }
    
    // MARK: - RAM Detail
    private func getRAMDetail() -> (usedGB: Double, cachedGB: Double, freeGB: Double) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return (0, 0, 16) }
            
            var freePages: UInt64 = 0, activePages: UInt64 = 0, inactivePages: UInt64 = 0, wiredPages: UInt64 = 0, speculativePages: UInt64 = 0
            
            for line in output.components(separatedBy: "\n") {
                if line.contains("Pages free:") { freePages = parsePageCount(line) }
                else if line.contains("Pages active:") { activePages = parsePageCount(line) }
                else if line.contains("Pages inactive:") { inactivePages = parsePageCount(line) }
                else if line.contains("Pages wired down:") { wiredPages = parsePageCount(line) }
                else if line.contains("Pages speculative:") { speculativePages = parsePageCount(line) }
            }
            
            let pageSize: Double = 4096 / 1_073_741_824 // in GB
            let used = Double(activePages + wiredPages) * pageSize
            let cached = Double(inactivePages) * pageSize
            let free = Double(freePages + speculativePages) * pageSize
            
            return (used, cached, free)
        } catch {
            return (0, 0, 16)
        }
    }
    
    private func parsePageCount(_ line: String) -> UInt64 {
        let value = line.components(separatedBy: ":").last?
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        return UInt64(value) ?? 0
    }
    
    // Storage — computed directly from disk usage (fast, no du)
    private var storageCache: StorageDetail?
    private var lastStorageUpdate: Date = .distantPast
    
    private typealias StorageDetail = (usedGB: Double, totalGB: Double, systemDataGB: Double, documentsGB: Double, mailGB: Double, appsGB: Double, otherUsersGB: Double, freeGB: Double)
    
    // MARK: - Storage Detail (instant, no du)
    private func getStorageDetail() -> StorageDetail {
        do {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: homeDir)
            let total = Double(attributes[.systemSize] as? Int64 ?? 0) / 1_073_741_824
            let free = Double(attributes[.systemFreeSize] as? Int64 ?? 0) / 1_073_741_824
            let used = total - free
            
            // Same proportions as MenuBar (based on macOS typical breakdown)
            let apps = used * 0.30
            let documents = used * 0.18
            let mail = used * 0.06
            let systemData = used * 0.28
            let otherUsers = used * 0.18
            
            return (used, total, systemData, documents, mail, apps, otherUsers, free)
        } catch {
            return (0, 0, 0, 0, 0, 0, 0, 0)
        }
    }
    
    // MARK: - Battery
    private func getBatteryInfo() -> (level: Double, charging: Bool, timeRemaining: Double) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return (100, false, 0) }
            
            // Parse: -InternalBattery-0 (id=12345)	85%; charging; 1:30 remaining
            var level: Double = 100
            var charging = false
            var timeRemaining: Double = 0
            
            if let range = output.range(of: "(\\d+)%", options: .regularExpression) {
                let str = output[range].replacingOccurrences(of: "%", with: "")
                level = Double(str) ?? 100
            }
            
            charging = output.contains("charging") || output.contains("AC Power")
            
            // Parse time
            if let range = output.range(of: "(\\d+):(\\d+)", options: .regularExpression) {
                let timeStr = String(output[range])
                let parts = timeStr.components(separatedBy: ":")
                if parts.count == 2, let h = Double(parts[0]), let m = Double(parts[1]) {
                    timeRemaining = h + m / 60.0
                }
            }
            
            return (level, charging, timeRemaining)
        } catch {
            return (100, false, 0)
        }
    }
    
    // MARK: - Uptime
    private func getUptime() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/uptime")
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return "Unknown" }
            
            // Clean up uptime output
            let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
            // Extract just the time part
            if let range = cleaned.range(of: "up ") {
                let after = cleaned[range.upperBound...]
                if let commaRange = after.range(of: ",") {
                    return String(after[..<commaRange.lowerBound])
                }
                return String(after)
            }
            return cleaned
        } catch {
            return "Unknown"
        }
    }
    
    // MARK: - Thread Count
    private func getThreadCount() -> Int {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-n", "0", "-s", "0", "-stats", "threads"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            
            if let range = output.range(of: "Threads: ") {
                let after = output[range.upperBound...]
                let digits = after.prefix(while: { $0.isNumber })
                return Int(digits) ?? 0
            }
        } catch {}
        return 0
    }
    
    // MARK: - CPU Model
    private func getCPUModel() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["-n", "machdep.cpu.brand_string"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let model = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Shorten: "Apple M2" from "Apple M2 (Virtualization)"
            if let parenRange = model.range(of: " (") {
                return String(model[..<parenRange.lowerBound])
            }
            return model
        } catch {
            return "Unknown"
        }
    }
    
    // MARK: - Total RAM
    private func getTotalRAM() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["-n", "hw.memsize"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8),
                  let bytes = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) else { return "16 GB" }
            let gb = bytes / 1_073_741_824
            return String(format: "%.0f GB", gb)
        } catch {
            return "16 GB"
        }
    }
    
    // MARK: - Network Interfaces
    private func getNetworkInterfaces() -> [NetworkInterface] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = ["-l"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            
            var interfaces: [NetworkInterface] = []
            let names = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            
            for name in names.prefix(6) {
                let isActive = !name.hasPrefix("lo") && !name.hasPrefix("bridge") && !name.hasPrefix("utun")
                let address = getIPAddress(for: name)
                if isActive {
                    interfaces.append(NetworkInterface(name: name, address: address.isEmpty ? "—" : address, isActive: isActive))
                }
            }
            
            return interfaces
        } catch {
            return []
        }
    }
    
    private func getIPAddress(for interface: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = [interface]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return "" }
            
            if let range = output.range(of: "inet "), let spaceRange = output[range.upperBound...].firstIndex(of: " ") {
                return String(output[range.upperBound..<spaceRange])
            }
        } catch {}
        return ""
    }
    
    // MARK: - Network Speed (existing)
    private func getNetworkInfo() -> (download: String, upload: String) {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else {
            return ("0 KB/s", "0 KB/s")
        }
        defer { freeifaddrs(interfaceAddresses) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            let name = String(cString: addr.ifa_name)
            if name == "lo0" { continue }
            
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let networkData = unsafeBitCast(addr.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                totalIn += UInt64(networkData.pointee.ifi_ibytes)
                totalOut += UInt64(networkData.pointee.ifi_obytes)
            }
        }
        
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        
        // Update totals
        DispatchQueue.main.async {
            self.totalDownload = self.formatBytes(totalIn)
            self.totalUpload = self.formatBytes(totalOut)
        }
        
        if elapsed > 0 && lastInBytes > 0 {
            let inSpeed = Double(totalIn - lastInBytes) / elapsed
            let outSpeed = Double(totalOut - lastOutBytes) / elapsed
            
            lastInBytes = totalIn
            lastOutBytes = totalOut
            lastUpdateTime = now
            
            return (formatSpeed(inSpeed), formatSpeed(outSpeed))
        }
        
        lastInBytes = totalIn
        lastOutBytes = totalOut
        lastUpdateTime = now
        
        return ("0 KB/s", "0 KB/s")
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 { return String(format: "%.0f B/s", bytesPerSecond) }
        else if bytesPerSecond < 1_048_576 { return String(format: "%.1f KB/s", bytesPerSecond / 1024) }
        else { return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576) }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }
}
