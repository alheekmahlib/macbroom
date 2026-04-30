import SwiftUI
import Combine

@MainActor
class RamBoosterViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var memoryInfo: MemoryInfo = RamBoosterService.getMemoryInfo()
    @Published var topApps: [AppMemoryInfo] = []
    @Published var expandedAppID: UUID? = nil
    @Published var isFreeing = false
    @Published var freedBytes: UInt64 = 0
    @Published var showFreedResult = false
    @Published var beforeInfo: MemoryInfo?
    
    // Auto-monitor
    @Published var isMonitoring = true
    @Published var lastMonitorUpdate = Date()
    @Published var monitorInterval: TimeInterval = 5.0
    
    // History for sparkline
    @Published var pressureHistory: [Double] = []
    private let maxHistoryCount = 60
    
    private var monitorTimer: Timer?
    
    // MARK: - Computed
    
    var totalRAMString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryInfo.totalBytes), countStyle: .memory)
    }
    
    var freeRAMString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryInfo.freeBytes), countStyle: .memory)
    }
    
    var usedRAMString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryInfo.usedBytes), countStyle: .memory)
    }
    
    var availableRAMString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryInfo.availableBytes), countStyle: .memory)
    }
    
    var freedRAMString: String {
        ByteCountFormatter.string(fromByteCount: Int64(freedBytes), countStyle: .memory)
    }
    
    var pressurePercent: Int {
        Int(memoryInfo.usagePercent * 100)
    }
    
    // MARK: - Init
    init() {
        refresh()
        startMonitoring()
    }
    
    deinit {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        guard monitorTimer == nil else { return }
        isMonitoring = true
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: monitorInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }
    
    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    func setMonitorInterval(_ interval: TimeInterval) {
        monitorInterval = interval
        if isMonitoring {
            stopMonitoring()
            startMonitoring()
        }
    }
    
    // MARK: - Refresh
    func refresh() {
        memoryInfo = RamBoosterService.getMemoryInfo()
        lastMonitorUpdate = Date()
        
        pressureHistory.append(memoryInfo.usagePercent)
        if pressureHistory.count > maxHistoryCount {
            pressureHistory.removeFirst()
        }
        
        // Refresh apps on background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let apps = RamBoosterService.getTopApps(limit: 12)
            DispatchQueue.main.async {
                self?.topApps = apps
            }
        }
    }
    
    // MARK: - Free RAM
    func freeUpRAM() {
        guard !isFreeing else { return }
        
        isFreeing = true
        showFreedResult = false
        beforeInfo = memoryInfo
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let freed = RamBoosterService.freeUpRAM()
            
            DispatchQueue.main.async {
                self?.freedBytes = freed
                self?.isFreeing = false
                self?.showFreedResult = true
                self?.refresh()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.showFreedResult = false
                }
            }
        }
    }
    
    // MARK: - Toggle app expansion
    func toggleAppExpansion(_ app: AppMemoryInfo) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            expandedAppID = expandedAppID == app.id ? nil : app.id
        }
    }
}
