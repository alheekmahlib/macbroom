import Foundation
import SwiftUI

class SystemInfoService {
    static let shared = SystemInfoService()
    
    private init() {}
    
    func updateSystemInfo(completion: @escaping (Result<SystemInfo, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var info = SystemInfo(
                cpuUsage: 0,
                ramUsage: 0,
                storageUsed: 0,
                storageCapacity: 0,
                temperature: 0,
                fanSpeed: 0
            )
            
            info.cpuUsage = self.getCPUUsage()
            info.ramUsage = self.getRAMUsage()
            
            let storage = self.getStorageInfo()
            info.storageUsed = storage.used
            info.storageCapacity = storage.capacity
            
            info.temperature = self.getTemperature()
            
            completion(.success(info))
        }
    }
    
    // MARK: - CPU Usage (safe fallback via ps command)
    private func getCPUUsage() -> Double {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-n", "0", "-s", "0"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            
            // Parse "CPU usage: X.X% user, Y.Y% sys, Z.Z% idle"
            if let range = output.range(of: "CPU usage:") {
                let substring = output[range.lowerBound...]
                // Find idle percentage
                let pattern = "([0-9]+\\.[0-9]+)% idle"
                if let idleRange = substring.range(of: pattern, options: .regularExpression) {
                    let idleStr = substring[idleRange].replacingOccurrences(of: "% idle", with: "")
                    if let idle = Double(idleStr) {
                        return max(0, (100.0 - idle) / 100.0)
                    }
                }
            }
        } catch {}
        return 0
    }
    
    // MARK: - RAM Usage (safe vm_stat approach)
    private func getRAMUsage() -> Double {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat"
        )
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            
            var freePages: UInt64 = 0
            var activePages: UInt64 = 0
            var inactivePages: UInt64 = 0
            var wiredPages: UInt64 = 0
            
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                if line.contains("Pages free:") {
                    let value = line.replacingOccurrences(of: "Pages free:", with: "")
                        .replacingOccurrences(of: ".", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    freePages = UInt64(value) ?? 0
                } else if line.contains("Pages active:") {
                    let value = line.replacingOccurrences(of: "Pages active:", with: "")
                        .replacingOccurrences(of: ".", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    activePages = UInt64(value) ?? 0
                } else if line.contains("Pages inactive:") {
                    let value = line.replacingOccurrences(of: "Pages inactive:", with: "")
                        .replacingOccurrences(of: ".", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    inactivePages = UInt64(value) ?? 0
                } else if line.contains("Pages wired down:") {
                    let value = line.replacingOccurrences(of: "Pages wired down:", with: "")
                        .replacingOccurrences(of: ".", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    wiredPages = UInt64(value) ?? 0
                }
            }
            
            let pageSize: UInt64 = 4096
            let used = (activePages + wiredPages) * pageSize
            let total = (activePages + wiredPages + freePages + inactivePages) * pageSize
            
            return total > 0 ? Double(used) / Double(total) : 0
        } catch {
            return 0
        }
    }
    
    // MARK: - Storage
    private func getStorageInfo() -> (used: Int64, capacity: Int64) {
        do {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: homeDir)
            let total = (attributes[.systemSize] as? Int64) ?? 0
            let free = (attributes[.systemFreeSize] as? Int64) ?? 0
            return (used: total - free, capacity: total)
        } catch {
            return (used: 0, capacity: 0)
        }
    }
    
    // MARK: - Temperature (safe shell approach)
    private func getTemperature() -> Double {
        // Try using `sudo powermetrics` won't work without privileges
        // Fallback: read from IOKit via ioreg
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ioreg")
        process.arguments = ["-r", "-n", "AppleSMC"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 45.0 }
            
            // Look for temperature key
            if let range = output.range(of: "\"Temperature\" = ") {
                let substring = output[range.upperBound...]
                let digits = substring.prefix(while: { $0.isNumber || $0 == "." })
                if let temp = Double(digits) {
                    return temp / 100.0 // Apple reports temp * 100
                }
            }
        } catch {}
        
        return 45.0 // Safe fallback
    }
    
    // MARK: - Network Speed
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var lastNetworkTime: Date = Date()
    private var isFirstNetworkRead: Bool = true
    
    struct NetworkSpeed {
        let upload: UInt64    // bytes/sec
        let download: UInt64  // bytes/sec
    }
    
    func getNetworkSpeed() -> NetworkSpeed {
        let currentIn = getNetworkBytes(direction: "ibytes")
        let currentOut = getNetworkBytes(direction: "obytes")
        
        let now = Date()
        
        // First read — just store baseline, return 0
        if isFirstNetworkRead {
            lastBytesIn = currentIn
            lastBytesOut = currentOut
            lastNetworkTime = now
            isFirstNetworkRead = false
            return NetworkSpeed(upload: 0, download: 0)
        }
        
        let elapsed = now.timeIntervalSince(lastNetworkTime)
        
        defer {
            lastBytesIn = currentIn
            lastBytesOut = currentOut
            lastNetworkTime = now
        }
        
        guard elapsed > 0.1 else {
            return NetworkSpeed(upload: 0, download: 0)
        }
        
        let elapsedUInt = UInt64(max(1, elapsed))
        let uploadSpeed = currentOut >= lastBytesOut ? (currentOut - lastBytesOut) / elapsedUInt : 0
        let downloadSpeed = currentIn >= lastBytesIn ? (currentIn - lastBytesIn) / elapsedUInt : 0
        
        return NetworkSpeed(upload: uploadSpeed, download: downloadSpeed)
    }
    
    private func getNetworkBytes(direction: String) -> UInt64 {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/netstat")
        process.arguments = ["-ibn"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            
            var totalBytes: UInt64 = 0
            let lines = output.components(separatedBy: "\n")
            
            for line in lines {
                // Only count Link lines (active interfaces)
                guard line.contains("<Link#>") else { continue }
                
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 10 else { continue }
                
                // Skip loopback
                let iface = String(parts[0])
                if iface.hasPrefix("lo") { continue }
                
                // ibytes = index 6, obytes = index 9
                let byteIndex = direction == "ibytes" ? 6 : 9
                if let bytes = UInt64(String(parts[byteIndex])) {
                    totalBytes += bytes
                }
            }
            
            return totalBytes
        } catch {
            return 0
        }
    }
    
    // MARK: - CPU Temperature (improved)
    func getCPUTemperature() -> Double {
        // Try ioreg first
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ioreg")
        process.arguments = ["-r", "-n", "AppleSMC"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return -1 }
            
            // Search for CPU temperature
            let patterns = ["\"Temperature\" = ", "\"cpu-temp\" = ", "\"TCXC\" = "]
            for pattern in patterns {
                if let range = output.range(of: pattern) {
                    let substring = output[range.upperBound...]
                    let digits = substring.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" })
                    if let temp = Double(digits), temp > 0 {
                        // Apple SMC reports temp scaled by 100 on some hardware
                        return temp > 200 ? temp / 100.0 : temp
                    }
                }
            }
        } catch {}
        
        return -1 // Not available
    }
    
    // MARK: - Top Processes
    func getTopProcesses(limit: Int = 10) -> [AppProcessInfo] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-arc", "-%cpu", "-o", "pid=,pcpu=,rss=,comm="]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            
            var processes: [AppProcessInfo] = []
            let lines = output.components(separatedBy: .newlines).dropFirst()
            
            for line in lines.prefix(limit) {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 4,
                      let pid = Int32(parts[0]),
                      let cpu = Double(parts[1]),
                      let rss = Double(parts[2]) else { continue }
                
                let name = String(parts[3...].joined(separator: " "))
                let shortName = (name as NSString).lastPathComponent
                
                processes.append(AppProcessInfo(
                    name: shortName,
                    cpuUsage: cpu,
                    ramMB: rss / 1024.0,
                    pid: pid
                ))
            }
            
            return processes
        } catch {
            return []
        }
    }
}
