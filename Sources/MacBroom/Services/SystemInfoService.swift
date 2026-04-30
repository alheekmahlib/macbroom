import Foundation
import SwiftUI
import Darwin.Mach
import IOKit

class SystemInfoService {
    static let shared = SystemInfoService()
    
    private init() {}
    
    // MARK: - CPU Usage (Native: host_processor_info)
    
    private var prevUserTicks: UInt64 = 0
    private var prevSystemTicks: UInt64 = 0
    private var prevIdleTicks: UInt64 = 0
    private var prevNiceTicks: UInt64 = 0
    
    /// CPU usage based on delta between calls (accurate, matches Activity Monitor behavior)
    func getCPUUsageDelta() -> (total: Double, user: Double, system: Double, idle: Double) {
        var numCPU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPU, &cpuInfo, &numCPUInfo)
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return (0, 0, 0, 100)
        }
        
        defer {
            let cpuInfoSize = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), cpuInfoSize)
        }
        
        var currentUser: UInt64 = 0
        var currentSystem: UInt64 = 0
        var currentIdle: UInt64 = 0
        var currentNice: UInt64 = 0
        
        let coreCount = Int(numCPU)
        let stateMax = Int(CPU_STATE_MAX)
        let stateUser = Int(CPU_STATE_USER)
        let stateSystem = Int(CPU_STATE_SYSTEM)
        let stateIdle = Int(CPU_STATE_IDLE)
        let stateNice = Int(CPU_STATE_NICE)
        
        for i in 0..<coreCount {
            let offset = i * stateMax
            currentUser   += UInt64(cpuInfo[offset + stateUser])
            currentSystem += UInt64(cpuInfo[offset + stateSystem])
            currentIdle   += UInt64(cpuInfo[offset + stateIdle])
            currentNice   += UInt64(cpuInfo[offset + stateNice])
        }
        
        let dUser   = currentUser > prevUserTicks ? currentUser - prevUserTicks : 0
        let dSystem = currentSystem > prevSystemTicks ? currentSystem - prevSystemTicks : 0
        let dIdle   = currentIdle > prevIdleTicks ? currentIdle - prevIdleTicks : 0
        let dNice   = currentNice > prevNiceTicks ? currentNice - prevNiceTicks : 0
        
        prevUserTicks = currentUser
        prevSystemTicks = currentSystem
        prevIdleTicks = currentIdle
        prevNiceTicks = currentNice
        
        let dTotal = dUser + dSystem + dIdle + dNice
        guard dTotal > 0 else { return (0, 0, 0, 100) }
        
        let userPct   = Double(dUser) / Double(dTotal) * 100.0
        let systemPct = Double(dSystem) / Double(dTotal) * 100.0
        let idlePct   = Double(dIdle) / Double(dTotal) * 100.0
        let totalPct  = 100.0 - idlePct
        
        return (totalPct, userPct, systemPct, idlePct)
    }
    
    // MARK: - RAM Usage (Native: host_statistics64)
    
    func getRAMInfo() -> (used: Double, cached: Double, free: Double, total: UInt64, pressureLevel: Int) {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        
        var hostInfo = vm_statistics64_data_t()
        var hostCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &hostCount)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (0, 0, Double(totalRAM), totalRAM, 1)
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let freePages       = UInt64(hostInfo.free_count) * pageSize
        let inactivePages   = UInt64(hostInfo.inactive_count) * pageSize
        let speculativePages = UInt64(hostInfo.speculative_count) * pageSize
        let compressedPages = UInt64(hostInfo.compressor_page_count) * pageSize
        let purgeablePages  = UInt64(hostInfo.purgeable_count) * pageSize
        let externalPages   = UInt64(hostInfo.external_page_count) * pageSize
        
        let gb: UInt64 = 1_000_000_000
        
        // Available = free + inactive + speculative + purgeable + external (reclaimable)
        let available = freePages + inactivePages + speculativePages + purgeablePages + externalPages
        let used = totalRAM > available ? totalRAM - available : 0
        
        // Pressure level (1=normal, 2=warning, 3=critical, 4=urgent)
        let availableRatio = Double(available) / Double(totalRAM)
        let pressureLevel: Int
        switch availableRatio {
        case 0.30...1.0: pressureLevel = 1
        case 0.15..<0.30: pressureLevel = 2
        case 0.05..<0.15: pressureLevel = 3
        default: pressureLevel = 4
        }
        
        return (
            used: Double(used) / Double(gb),
            cached: Double(inactivePages + compressedPages) / Double(gb),
            free: Double(available) / Double(gb),
            total: totalRAM,
            pressureLevel: pressureLevel
        )
    }
    
    // MARK: - Storage (Matches About This Mac & System Settings)
    
    /// Get storage info that matches Apple's "About This Mac".
    /// Key insights:
    /// 1. Apple uses decimal GB (1 GB = 1,000,000,000 bytes), not binary GiB (1,073,741,824)
    /// 2. `volumeAvailableCapacityForImportantUsageKey` includes Purgeable Space (Time Machine snapshots, iCloud cache)
    /// 3. This is what users expect to see — matches Finder and System Settings
    
    func getStorageInfo() -> (used: Int64, capacity: Int64, available: Int64) {
        let fileURL = URL(fileURLWithPath: "/")
        
        do {
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            
            guard let totalByte = values.volumeTotalCapacity,
                  let availableByte = values.volumeAvailableCapacityForImportantUsage else {
                return fallbackStorageInfo()
            }
            
            let total = Int64(totalByte)
            let available = Int64(availableByte)
            let used = total - available
            
            return (used: max(0, used), capacity: total, available: available)
        } catch {
            return fallbackStorageInfo()
        }
    }
    
    private func fallbackStorageInfo() -> (used: Int64, capacity: Int64, available: Int64) {
        var info = statfs()
        guard statfs("/", &info) == 0 else {
            return (0, 0, 0)
        }
        let blockSize = Int64(info.f_bsize)
        let total = Int64(info.f_blocks) * blockSize
        let free = Int64(info.f_bavail) * blockSize
        let used = total - free
        return (used: max(0, used), capacity: total, available: free)
    }
    
    // MARK: - Network (Native: getifaddrs)
    
    private var lastNetInBytes: UInt64 = 0
    private var lastNetOutBytes: UInt64 = 0
    private var lastNetTime: Date = Date()
    private var isFirstNetRead: Bool = true
    
    struct NetworkStats {
        let downloadSpeed: UInt64
        let uploadSpeed: UInt64
        let totalDownload: UInt64
        let totalUpload: UInt64
    }
    
    func getNetworkStats() -> NetworkStats {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else {
            return NetworkStats(downloadSpeed: 0, uploadSpeed: 0, totalDownload: 0, totalUpload: 0)
        }
        defer { freeifaddrs(interfaceAddresses) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            let name = String(cString: addr.ifa_name)
            
            if name == "lo0" || name.hasPrefix("utun") || name.hasPrefix("bridge") { continue }
            
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let networkData = unsafeBitCast(addr.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                totalIn += UInt64(networkData.pointee.ifi_ibytes)
                totalOut += UInt64(networkData.pointee.ifi_obytes)
            }
        }
        
        let now = Date()
        
        if isFirstNetRead {
            lastNetInBytes = totalIn
            lastNetOutBytes = totalOut
            lastNetTime = now
            isFirstNetRead = false
            return NetworkStats(downloadSpeed: 0, uploadSpeed: 0, totalDownload: totalIn, totalUpload: totalOut)
        }
        
        let elapsed = now.timeIntervalSince(lastNetTime)
        guard elapsed > 0.1 else {
            return NetworkStats(downloadSpeed: 0, uploadSpeed: 0, totalDownload: totalIn, totalUpload: totalOut)
        }
        
        let elapsedUInt = UInt64(max(1, elapsed))
        let downloadSpeed = totalIn >= lastNetInBytes ? (totalIn - lastNetInBytes) / elapsedUInt : 0
        let uploadSpeed = totalOut >= lastNetOutBytes ? (totalOut - lastNetOutBytes) / elapsedUInt : 0
        
        lastNetInBytes = totalIn
        lastNetOutBytes = totalOut
        lastNetTime = now
        
        return NetworkStats(
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            totalDownload: totalIn,
            totalUpload: totalOut
        )
    }
    
    // MARK: - Network Interfaces (Native: getifaddrs)
    
    struct InterfaceInfo {
        let name: String
        let address: String
        let isActive: Bool
    }
    
    func getNetworkInterfaces() -> [InterfaceInfo] {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else {
            return []
        }
        defer { freeifaddrs(interfaceAddresses) }
        
        var ipv4Map: [String: String] = [:]
        var activeInterfaces: Set<String> = []
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            let name = String(cString: addr.ifa_name)
            
            if name == "lo0" || name.hasPrefix("bridge") || name.hasPrefix("utun") { continue }
            
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                var addrBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var addrIn = addr.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                inet_ntop(AF_INET, &addrIn.sin_addr, &addrBuf, socklen_t(INET_ADDRSTRLEN))
                let ip = String(cString: addrBuf)
                if ip != "0.0.0.0" {
                    ipv4Map[name] = ip
                }
            }
            
            let flags = Int32(addr.ifa_flags)
            if (flags & IFF_UP) != 0 && (flags & IFF_LOOPBACK) == 0 {
                activeInterfaces.insert(name)
            }
        }
        
        return activeInterfaces.sorted().prefix(6).map { name in
            InterfaceInfo(name: name, address: ipv4Map[name] ?? "—", isActive: true)
        }
    }
    
    // MARK: - Temperature (IOKit — AppleSMC)
    
    func getTemperature() -> Double {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return -1 }
        defer { IOObjectRelease(service) }
        
        // Try known SMC temperature keys
        for key in ["TCXC", "TC0P", "Th1H", "TCXC"] {
            if let temp = readSMCValue(service: service, key: key) {
                return temp
            }
        }
        
        return -1
    }
    
    private func readSMCValue(service: io_object_t, key: String) -> Double? {
        let keyChars = [UInt8](key.utf8)
        guard keyChars.count == 4 else { return nil }
        
        var input = SMCKeyData(
            key: (keyChars[0], keyChars[1], keyChars[2], keyChars[3]),
            vers: 0, pLimitData: 0, kernelVersion: 0,
            data8: SMC_CMD_READ_KEYINFO, data32: 0,
            bytes: (0, 0, 0, 0, 0),
            data: (0, 0, 0, 0, 0, 0, 0, 0),
            result: 0, status: 0, data8_2: 0, data32_2: 0
        )
        
        var output = input
        var outputSize = Int(MemoryLayout<SMCKeyData>.size)
        
        let kr = IOConnectCallStructMethod(
            service,
            UInt32(KERNEL_INDEX_SMC),
            &input, Int(MemoryLayout<SMCKeyData>.size),
            &output, &outputSize
        )
        
        guard kr == KERN_SUCCESS else { return nil }
        
        // Now read the actual bytes
        input.data8 = SMC_CMD_READ_BYTES
        input.data32 = output.data32
        
        var output2 = input
        outputSize = Int(MemoryLayout<SMCKeyData>.size)
        
        let kr2 = IOConnectCallStructMethod(
            service,
            UInt32(KERNEL_INDEX_SMC),
            &input, Int(MemoryLayout<SMCKeyData>.size),
            &output2, &outputSize
        )
        
        guard kr2 == KERN_SUCCESS else { return nil }
        
        let b0 = Double(output2.bytes.0)
        let b1 = Double(output2.bytes.1)
        let temp = b0 + b1 / 256.0
        
        return (temp > 0 && temp < 150) ? temp : nil
    }
    
    // MARK: - Top Processes (Native: libproc)
    
    func getTopProcesses(limit: Int = 10) -> [AppProcessInfo] {
        let procType = UInt32(PROC_ALL_PIDS)
        var bufSize = proc_listpids(procType, 0, nil, 0)
        guard bufSize > 0 else { return [] }
        
        var pids = [Int32](repeating: 0, count: Int(bufSize) / MemoryLayout<Int32>.size)
        bufSize = proc_listpids(procType, 0, &pids, bufSize)
        let pidCount = Int(bufSize) / MemoryLayout<Int32>.size
        
        var processes: [(pid: Int32, name: String, rss: Double)] = []
        
        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }
            
            var taskInfo = proc_taskinfo()
            let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            guard taskResult > 0 else { continue }
            
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
            
            if name == "kernel_task" || name.isEmpty { continue }
            
            let rss = Double(taskInfo.pti_resident_size) / (1024 * 1024)
            processes.append((pid: pid, name: name, rss: rss))
        }
        
        // Sort by RSS descending
        processes.sort { $0.rss > $1.rss }
        
        return processes.prefix(limit).map { proc in
            let shortName = proc.name.components(separatedBy: "/").last ?? proc.name
            return AppProcessInfo(
                name: shortName,
                cpuUsage: 0,
                ramMB: proc.rss,
                pid: proc.pid
            )
        }
    }
    
    // MARK: - Battery (Native: IOKit)
    
    func getBatteryInfo() -> (level: Double, charging: Bool, timeRemaining: Double) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return (100, false, 0) }
        defer { IOObjectRelease(service) }
        
        var level: Double = 100
        var charging: Bool = false
        var timeRemaining: Double = 0
        
        if let current = getIOPropertyInt(service, "CurrentCapacity"),
           let max = getIOPropertyInt(service, "MaxCapacity") {
            level = Double(current) / Double(max) * 100.0
        }
        
        if let flags = getIOPropertyInt(service, "Flags") {
            charging = (flags & 0x04) != 0
        }
        
        if let time = getIOPropertyInt(service, "TimeRemaining") {
            timeRemaining = Double(time) / 60.0
        }
        
        return (level, charging, timeRemaining)
    }
    
    private func getIOPropertyInt(_ service: io_object_t, _ key: String) -> Int32? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return (value.takeRetainedValue() as? NSNumber)?.int32Value
    }
    
    // MARK: - CPU Model (Native: sysctl)
    
    func getCPUModel() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        
        let model = String(cString: buffer)
        if let parenRange = model.range(of: " (") {
            return String(model[..<parenRange.lowerBound])
        }
        return model
    }
    
    // MARK: - Thread Count (Native: proc_pidinfo)
    
    func getThreadCount() -> Int {
        let procType = UInt32(PROC_ALL_PIDS)
        var bufSize = proc_listpids(procType, 0, nil, 0)
        guard bufSize > 0 else { return 0 }
        
        var pids = [Int32](repeating: 0, count: Int(bufSize) / MemoryLayout<Int32>.size)
        bufSize = proc_listpids(procType, 0, &pids, bufSize)
        let pidCount = Int(bufSize) / MemoryLayout<Int32>.size
        
        var totalThreads: Int = 0
        
        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }
            
            var taskInfo = proc_taskinfo()
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            if result > 0 {
                totalThreads += Int(taskInfo.pti_threadnum)
            }
        }
        
        return totalThreads
    }
    
    // MARK: - Uptime (Native: sysctl)
    
    func getUptime() -> String {
        var timeval = timeval()
        var size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &timeval, &size, nil, 0)
        
        let bootTime = Date(timeIntervalSince1970: Double(timeval.tv_sec) + Double(timeval.tv_usec) / 1_000_000)
        let interval = Date().timeIntervalSince(bootTime)
        
        let hours = Int(interval) / 3600
        let days = hours / 24
        
        if days > 0 {
            return "\(days)d \(hours % 24)h"
        } else if hours > 0 {
            let minutes = (Int(interval) % 3600) / 60
            return "\(hours)h \(minutes)m"
        } else {
            let minutes = Int(interval) / 60
            return "\(minutes)m"
        }
    }
    
    // MARK: - Legacy compatibility
    
    func updateSystemInfo(completion: @escaping (Result<SystemInfo, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let cpu = getCPUUsageDelta()
            let ramInfo = getRAMInfo()
            let storage = getStorageInfo()
            let temp = getTemperature()
            
            let totalGB = Double(ramInfo.total) / 1_000_000_000
            let ramUsageFraction = totalGB > 0 ? ramInfo.used / totalGB : 0
            
            let info = SystemInfo(
                cpuUsage: cpu.total / 100.0,
                ramUsage: ramUsageFraction,
                storageUsed: storage.used,
                storageCapacity: storage.capacity,
                temperature: temp > 0 ? temp : 45.0,
                fanSpeed: 0
            )
            
            completion(.success(info))
        }
    }
    
    /// Network speed (legacy compatibility)
    struct NetworkSpeed {
        let upload: UInt64
        let download: UInt64
    }
    
    func getNetworkSpeed() -> NetworkSpeed {
        let stats = getNetworkStats()
        return NetworkSpeed(upload: stats.uploadSpeed, download: stats.downloadSpeed)
    }
}

// MARK: - SMC Types for Temperature Reading

private let KERNEL_INDEX_SMC: Int = 2
private let SMC_CMD_READ_KEYINFO: UInt8 = 9
private let SMC_CMD_READ_BYTES: UInt8 = 5

private struct SMCKeyData {
    var key: (UInt8, UInt8, UInt8, UInt8)
    var vers: UInt32
    var pLimitData: UInt32
    var kernelVersion: UInt32
    var data8: UInt8
    var data32: UInt32
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8)
    var data: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)
    var result: UInt8
    var status: UInt8
    var data8_2: UInt8
    var data32_2: UInt32
}
