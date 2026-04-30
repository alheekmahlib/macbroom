import SwiftUI

class AppState: ObservableObject {
    @Published var selectedPage: Page = .home
    @Published var healthScore: Int = 0
    @Published var totalStorageUsed: Int64 = 0
    @Published var totalStorageCapacity: Int64 = 0
    @Published var cpuUsage: Double = 0
    @Published var ramUsage: Double = 0
    @Published var isScanning: Bool = false
    @Published var cleanedBytes: Int64 = 0
    @Published var menuBarVisible: Bool = true
    @Published var networkUpload: UInt64 = 0     // bytes/sec
    @Published var networkDownload: UInt64 = 0   // bytes/sec
    @Published var cpuTemperature: Double = -1   // -1 = N/A
    @Published var currentLanguage: AppLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "en") ?? .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    let licenseManager = LicenseManager.shared
    
    enum Page: String, CaseIterable {
        case home = "Home"
        case smartClean = "Smart Clean"
        case largeFiles = "Large Files"
        case diskAnalyzer = "Disk Analyzer"
        case ramBooster = "RAM Booster"
        case appUninstaller = "Apps"
        case systemMonitor = "Monitor"
        case settings = "Settings"
        
        func localizedName(_ lang: AppLanguage) -> String {
            switch self {
            case .home: return L.home(lang)
            case .smartClean: return L.smartClean(lang)
            case .largeFiles: return "Large Files"
            case .diskAnalyzer: return "Disk Analyzer"
            case .ramBooster: return "Free Up RAM"
            case .appUninstaller: return L.apps(lang)
            case .systemMonitor: return L.monitor(lang)
            case .settings: return L.settings(lang)
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .smartClean: return "sparkles"
            case .largeFiles: return "doc.badge.gearshape.fill"
            case .diskAnalyzer: return "chart.pie.fill"
            case .ramBooster: return "bolt.circle.fill"
            case .appUninstaller: return "archivebox.fill"
            case .systemMonitor: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    private var _refreshTimer: Timer?
    
    init() {
        refreshSystemInfo()
        startAutoRefresh()
    }
    
    private func startAutoRefresh() {
        _refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshSystemInfo()
        }
    }
    
    func refreshSystemInfo() {
        SystemInfoService.shared.updateSystemInfo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let info):
                    self?.cpuUsage = info.cpuUsage
                    self?.ramUsage = info.ramUsage
                self?.totalStorageUsed = info.storageUsed
                self?.totalStorageCapacity = info.storageCapacity
                self?.healthScore = self?.calculateHealthScore(info: info) ?? 0
            case .failure:
                break
            }
        }
        }
        
        // Network + Temp on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let speed = Self.getNetworkSpeedLive()
            let temp = SystemInfoService.shared.getTemperature()
            
            DispatchQueue.main.async {
                self?.networkUpload = speed.upload
                self?.networkDownload = speed.download
                self?.cpuTemperature = temp
            }
        }
    }
    
    // MARK: - Live Network (getifaddrs)
    private static var _lastInBytes: UInt64 = 0
    private static var _lastOutBytes: UInt64 = 0
    private static var _lastNetTime: Date = Date()
    private static var _firstNetRead: Bool = true
    
    private static func getNetworkSpeedLive() -> (upload: UInt64, download: UInt64) {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else {
            return (0, 0)
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
        
        if _firstNetRead {
            _lastInBytes = totalIn
            _lastOutBytes = totalOut
            _lastNetTime = now
            _firstNetRead = false
            return (0, 0)
        }
        
        let elapsed = now.timeIntervalSince(_lastNetTime)
        let uploadSpeed: UInt64
        let downloadSpeed: UInt64
        
        if elapsed > 0.1 {
            let elapsedDouble = Double(totalOut >= _lastOutBytes ? totalOut - _lastOutBytes : 0) / elapsed
            let downloadDouble = Double(totalIn >= _lastInBytes ? totalIn - _lastInBytes : 0) / elapsed
            uploadSpeed = UInt64(elapsedDouble)
            downloadSpeed = UInt64(downloadDouble)
        } else {
            uploadSpeed = 0
            downloadSpeed = 0
        }
        
        _lastInBytes = totalIn
        _lastOutBytes = totalOut
        _lastNetTime = now
        
        return (upload: uploadSpeed, download: downloadSpeed)
    }
    
    private func calculateHealthScore(info: SystemInfo) -> Int {
        let storagePercent = Double(info.storageUsed) / Double(info.storageCapacity)
        let ramScore = max(0, 100 - (info.ramUsage * 100))
        let storageScore = max(0, 100 - (storagePercent * 100))
        let cpuScore = max(0, 100 - (info.cpuUsage * 100))
        return Int((ramScore + storageScore + cpuScore) / 3)
    }
}
