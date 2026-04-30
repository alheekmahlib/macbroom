import SwiftUI

struct SystemMonitorView: View {
    @StateObject private var viewModel = SystemMonitorViewModel()
    @State private var timer: Timer?
    @State private var isVisible = false
    @State private var selectedTab: MonitorTab = .overview
    
    enum MonitorTab: String, CaseIterable {
        case overview = "Overview"
        case processes = "Processes"
        case network = "Network"
        case storage = "Storage"
        
        var icon: String {
            switch self {
            case .overview: return "gauge.with.dots.needle.bottom.50percent"
            case .processes: return "list.bullet.rectangle"
            case .network: return "network"
            case .storage: return "internaldrive"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            monitorHeader
            
            Divider().opacity(0.3)
            
            // Tab bar
            tabBar
            
            Divider().opacity(0.3)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .processes:
                        processesContent
                    case .network:
                        networkContent
                    case .storage:
                        storageContent
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            isVisible = true
            viewModel.startMonitoring()
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                viewModel.update()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - Header
    private var monitorHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Monitor")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text("Real-time performance monitoring")
                    .font(.system(size: 13))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
            Spacer()
            
            // Uptime
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Text(viewModel.uptime)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
            )
            
            // Live indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(MacBroomTheme.success)
                    .frame(width: 7, height: 7)
                    .modifier(PulseEffect())
                Text("Live")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.success)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(MacBroomTheme.success.opacity(0.08))
            )
        }
        .padding(24)
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(MonitorTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(MacBroomTheme.animationFast) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : MacBroomTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? MacBroomTheme.accent.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedTab == tab ? MacBroomTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - Overview Tab
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // CPU + RAM Row
            HStack(spacing: 12) {
                DetailedGaugeCard(
                    title: "CPU",
                    subtitle: viewModel.cpuModel,
                    value: viewModel.cpuUsage,
                    maxValue: 100,
                    color: MacBroomTheme.accent,
                    unit: "%",
                    details: [
                        ("User", String(format: "%.1f%%", viewModel.cpuUser)),
                        ("System", String(format: "%.1f%%", viewModel.cpuSystem)),
                        ("Idle", String(format: "%.1f%%", viewModel.cpuIdle)),
                    ],
                    cores: viewModel.cpuCoreCount,
                    index: 0,
                    isVisible: isVisible
                )
                DetailedGaugeCard(
                    title: "RAM",
                    subtitle: viewModel.totalRAM,
                    value: viewModel.ramUsage,
                    maxValue: 100,
                    color: MacBroomTheme.success,
                    unit: "%",
                    details: [
                        ("Used", String(format: "%.1f GB", viewModel.ramUsedGB)),
                        ("Cached", String(format: "%.1f GB", viewModel.ramCachedGB)),
                        ("Free", String(format: "%.1f GB", viewModel.ramFreeGB)),
                    ],
                    cores: nil,
                    index: 1,
                    isVisible: isVisible
                )
            }
            
            // Temperature + Battery Row
            HStack(spacing: 12) {
                MiniInfoCard(
                    icon: "thermometer.medium",
                    title: "Temperature",
                    value: viewModel.temperature >= 0 ? String(format: "%.0f°C", viewModel.temperature) : "N/A",
                    subtitle: viewModel.temperature >= 0 ? tempStatus : "Not available",
                    color: tempColor,
                    index: 2,
                    isVisible: isVisible
                )
                MiniInfoCard(
                    icon: "battery.75percent",
                    title: "Battery",
                    value: String(format: "%.0f%%", viewModel.batteryLevel),
                    subtitle: viewModel.batteryCharging ? "Charging" : String(format: "%.1f hrs remaining", viewModel.batteryTimeRemaining),
                    color: viewModel.batteryLevel > 20 ? MacBroomTheme.success : MacBroomTheme.danger,
                    index: 3,
                    isVisible: isVisible
                )
                MiniInfoCard(
                    icon: "fan",
                    title: "Fan Speed",
                    value: viewModel.fanSpeed > 0 ? "\(viewModel.fanSpeed) RPM" : "N/A",
                    subtitle: viewModel.fanSpeed > 0 ? fanStatus : "Not available",
                    color: MacBroomTheme.accentLight,
                    index: 4,
                    isVisible: isVisible
                )
            }
            
            // Network mini
            HStack(spacing: 12) {
                NetworkSpeedCard(
                    icon: "arrow.down.circle.fill",
                    title: "Download",
                    value: viewModel.networkDownload,
                    color: MacBroomTheme.accent,
                    total: viewModel.totalDownload
                )
                NetworkSpeedCard(
                    icon: "arrow.up.circle.fill",
                    title: "Upload",
                    value: viewModel.networkUpload,
                    color: MacBroomTheme.success,
                    total: viewModel.totalUpload
                )
            }
        }
    }
    
    // MARK: - Processes Tab
    private var processesContent: some View {
        VStack(spacing: 12) {
            // Summary
            HStack(spacing: 12) {
                ProcessSummaryCard(title: "Total Processes", value: "\(viewModel.topProcesses.count)", icon: "app.badge", color: MacBroomTheme.accent)
                ProcessSummaryCard(title: "Threads", value: "\(viewModel.threadCount)", icon: "line.3.horizontal", color: MacBroomTheme.success)
                ProcessSummaryCard(title: "Highest CPU", value: viewModel.topProcesses.first.map { String(format: "%.0f%%", $0.cpuUsage) } ?? "0%", icon: "flame", color: MacBroomTheme.warning)
            }
            
            // Table header
            HStack(spacing: 0) {
                Text("Process")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .frame(width: 60, alignment: .trailing)
                Text("CPU")
                    .frame(width: 80, alignment: .trailing)
                Text("RAM")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MacBroomTheme.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // Process list
            ForEach(Array(viewModel.topProcesses.enumerated()), id: \.element.id) { index, process in
                DetailedProcessRow(process: process, rank: index + 1)
                    .staggered(index: index, isVisible: isVisible)
            }
        }
    }
    
    // MARK: - Network Tab
    private var networkContent: some View {
        VStack(spacing: 16) {
            // Speed cards
            HStack(spacing: 12) {
                LargeNetworkCard(
                    icon: "arrow.down.circle.fill",
                    title: "Download Speed",
                    speed: viewModel.networkDownload,
                    total: viewModel.totalDownload,
                    color: MacBroomTheme.accent,
                    index: 0,
                    isVisible: isVisible
                )
                LargeNetworkCard(
                    icon: "arrow.up.circle.fill",
                    title: "Upload Speed",
                    speed: viewModel.networkUpload,
                    total: viewModel.totalUpload,
                    color: MacBroomTheme.success,
                    index: 1,
                    isVisible: isVisible
                )
            }
            
            // Network interfaces
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "network")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MacBroomTheme.accent)
                    Text("Active Interfaces")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                }
                
                ForEach(viewModel.networkInterfaces, id: \.name) { iface in
                    InterfaceRow(interface: iface)
                }
            }
            .cardStyle()
        }
    }
    
    // MARK: - Storage Tab
    private var storageContent: some View {
        VStack(spacing: 16) {
            // Main storage bar
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MacBroomTheme.warning)
                    Text("Macintosh HD")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f GB / %.0f GB", viewModel.storageUsedGB, viewModel.storageTotalGB))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                }
                
                // Multi-segment storage bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        // System Data
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MacBroomTheme.accent)
                            .frame(width: geo.size.width * CGFloat(viewModel.systemDataPercent))
                        // Apps
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MacBroomTheme.accentLight)
                            .frame(width: geo.size.width * CGFloat(viewModel.appsPercent))
                        // Documents
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MacBroomTheme.warning)
                            .frame(width: geo.size.width * CGFloat(viewModel.documentsPercent))
                        // Mail
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * CGFloat(viewModel.mailPercent))
                        // Other Users & Shared
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MacBroomTheme.danger.opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(viewModel.otherUsersPercent))
                        // Free
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                    }
                }
                .frame(height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                
                // Compact legend
                HStack(spacing: 10) {
                    LegendItem(color: Color(red: 0.25, green: 0.45, blue: 0.95), label: "System Data", value: String(format: "%.1f GB", viewModel.systemDataGB))
                    LegendItem(color: Color(red: 0.40, green: 0.60, blue: 1.0), label: "Apps", value: String(format: "%.1f GB", viewModel.appsGB))
                    LegendItem(color: Color(red: 1.0, green: 0.65, blue: 0.15), label: "Docs", value: String(format: "%.1f GB", viewModel.documentsGB))
                    LegendItem(color: Color.purple, label: "Mail", value: String(format: "%.1f GB", viewModel.mailGB))
                    LegendItem(color: Color(red: 0.95, green: 0.30, blue: 0.35).opacity(0.7), label: "Other Users & Shared", value: String(format: "%.1f GB", viewModel.otherUsersGB))
                    LegendItem(color: Color.white.opacity(0.15), label: "Free", value: String(format: "%.0f GB", viewModel.freeGB))
                    Spacer()
                }
            }
            .padding(10)
            
            // Disk info cards
            HStack(spacing: 12) {
                StorageInfoCard(title: "Total Capacity", value: String(format: "%.0f GB", viewModel.storageTotalGB), icon: "internaldrive")
                StorageInfoCard(title: "Available", value: String(format: "%.0f GB", viewModel.freeGB), icon: "externaldrive.badge.checkmark")
                StorageInfoCard(title: "Used", value: String(format: "%.0f GB", viewModel.storageUsedGB), icon: "externaldrive.badge.minus")
            }
        }
    }
    
    // MARK: - Helpers
    private var tempStatus: String {
        switch viewModel.temperature {
        case ..<45: return "Cool"
        case 45..<65: return "Normal"
        case 65..<80: return "Warm"
        default: return "Hot"
        }
    }
    
    private var tempColor: Color {
        switch viewModel.temperature {
        case ..<45: return MacBroomTheme.success
        case 45..<65: return MacBroomTheme.accent
        case 65..<80: return MacBroomTheme.warning
        default: return MacBroomTheme.danger
        }
    }
    
    private var fanStatus: String {
        switch viewModel.fanSpeed {
        case ..<2000: return "Quiet"
        case 2000..<4000: return "Normal"
        default: return "High"
        }
    }
}

// MARK: - Detailed Gauge Card
struct DetailedGaugeCard: View {
    let title: String
    let subtitle: String
    let value: Double
    let maxValue: Double
    let color: Color
    let unit: String
    let details: [(String, String)]
    let cores: Int?
    let index: Int
    let isVisible: Bool
    
    @State private var isHovered = false
    
    private var percent: Double { min(value / maxValue, 1.0) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(MacBroomTheme.textMuted)
                        .lineLimit(1)
                }
                Spacer()
                if let cores = cores {
                    Text("\(cores) cores")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(color.opacity(0.1)))
                }
            }
            
            // Gauge + Value
            HStack(spacing: 16) {
                AnimatedProgressRing(
                    progress: percent,
                    lineWidth: 6,
                    gradient: LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    size: 70
                )
                .overlay(
                    VStack(spacing: 0) {
                        Text(String(format: "%.0f", value))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(MacBroomTheme.textPrimary)
                            .contentTransition(.numericText())
                        Text(unit)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(MacBroomTheme.textSecondary)
                    }
                )
                
                // Details
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(details, id: \.0) { label, val in
                        HStack {
                            Circle()
                                .fill(color.opacity(0.4))
                                .frame(width: 4, height: 4)
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundStyle(MacBroomTheme.textSecondary)
                            Spacer()
                            Text(val)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(MacBroomTheme.textPrimary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .staggered(index: index, isVisible: isVisible)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
            .fill(Color.white.opacity(isHovered ? 0.06 : 0.03))
            .overlay(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                    .stroke(color.opacity(isHovered ? 0.2 : 0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: isHovered ? 8 : 4, y: 2)
            .animation(MacBroomTheme.animationFast, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Mini Info Card
struct MiniInfoCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let index: Int
    let isVisible: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(MacBroomTheme.textPrimary)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(MacBroomTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                .fill(Color.white.opacity(isHovered ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                        .stroke(color.opacity(isHovered ? 0.2 : 0.06), lineWidth: 1)
                )
        )
        .animation(MacBroomTheme.animationFast, value: isHovered)
        .onHover { isHovered = $0 }
        .staggered(index: index, isVisible: isVisible)
    }
}

// MARK: - Network Speed Card
struct NetworkSpeedCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let total: String
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
            }
            Spacer()
            Text("Total: \(total)")
                .font(.system(size: 9))
                .foregroundStyle(MacBroomTheme.textMuted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Process Summary Card
struct ProcessSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MacBroomTheme.textPrimary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(MacBroomTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Detailed Process Row
struct DetailedProcessRow: View {
    let process: AppProcessInfo
    let rank: Int
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? MacBroomTheme.accent : MacBroomTheme.textMuted)
                .frame(width: 24)
            
            // Name
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Text(process.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // PID
            Text("\(process.pid)")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(MacBroomTheme.textMuted)
                .frame(width: 60, alignment: .trailing)
            
            // CPU with mini bar
            HStack(spacing: 6) {
                MiniBar(value: process.cpuUsage / 100, color: cpuColor)
                Text(String(format: "%.1f%%", process.cpuUsage))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(width: 80, alignment: .trailing)
            
            // RAM
            Text(String(format: "%.0f MB", process.ramMB))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(MacBroomTheme.textSecondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
        )
        .animation(MacBroomTheme.animationFast, value: isHovered)
        .onHover { isHovered = $0 }
    }
    
    private var cpuColor: Color {
        switch process.cpuUsage {
        case ..<10: return MacBroomTheme.success
        case 10..<30: return MacBroomTheme.accent
        case 30..<60: return MacBroomTheme.warning
        default: return MacBroomTheme.danger
        }
    }
}

// MARK: - Mini Bar
struct MiniBar: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(value, 1.0)))
            }
        }
        .frame(width: 24, height: 4)
    }
}

// MARK: - Large Network Card
struct LargeNetworkCard: View {
    let icon: String
    let title: String
    let speed: String
    let total: String
    let color: Color
    let index: Int
    let isVisible: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                    Text(speed)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                }
                Spacer()
            }
            
            HStack {
                Text("Total: \(total)")
                    .font(.system(size: 11))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                        .stroke(color.opacity(0.08), lineWidth: 1)
                )
        )
        .staggered(index: index, isVisible: isVisible)
    }
}

// MARK: - Interface Row
struct InterfaceRow: View {
    let interface: NetworkInterface
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: interface.isActive ? "wifi" : "wifi.slash")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(interface.isActive ? MacBroomTheme.success : MacBroomTheme.textMuted)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(interface.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text(interface.address)
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textMuted)
            }
            
            Spacer()
            
            if interface.isActive {
                Text("Active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(MacBroomTheme.success.opacity(0.1)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.02))
        )
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
        }
    }
}

// MARK: - Storage Info Card
struct StorageInfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MacBroomTheme.accent)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MacBroomTheme.textPrimary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(MacBroomTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Card Style Modifier
// Using .cardStyle() from Animations.swift
