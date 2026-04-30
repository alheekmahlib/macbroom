import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isVisible = false
    
    private var lang: AppLanguage { appState.currentLanguage }
    
    private var cleanedGB: String {
        let gb = Double(appState.cleanedBytes) / 1_000_000_000
        return String(format: "%.1f GB", gb)
    }
    
    private var usedGB: Double {
        Double(appState.totalStorageUsed) / 1_000_000_000
    }
    
    private var totalGB: Double {
        Double(appState.totalStorageCapacity) / 1_000_000_000
    }
    
    private var storagePercent: Double {
        guard appState.totalStorageCapacity > 0 else { return 0 }
        return Double(appState.totalStorageUsed) / Double(appState.totalStorageCapacity)
    }
    
    private var ramUsedGB: Double { Double(appState.ramUsage) * 16.0 }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ── Header with Health Score ──
                healthHeader
                    .padding(.top, 32)
                    .padding(.horizontal, 28)
                
                // ── CPU + RAM Row ──
                HStack(spacing: 12) {
                    cpuCard
                    ramCard
                }
                .padding(.horizontal, 28)
                
                // ── Storage Card ──
                storageCard
                    .padding(.horizontal, 28)
                
                // ── Network Card ──
                networkCard
                    .padding(.horizontal, 28)
                
                // ── Quick Actions ──
                quickActionsSection
                    .padding(.horizontal, 28)
                
                Spacer(minLength: 32)
            }
        }
        .onAppear { isVisible = true }
    }
    
    // MARK: - Health Header
    private var healthHeader: some View {
        HStack(spacing: 16) {
            // Health Score Ring
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MacBroomTheme.accent.opacity(0.10), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)
                
                AnimatedProgressRing(
                    progress: Double(appState.healthScore) / 100,
                    lineWidth: 8,
                    gradient: appState.healthScore >= 70 ? MacBroomTheme.healthGoodGradient : MacBroomTheme.healthBadGradient,
                    size: 90
                )
                
                VStack(spacing: 2) {
                    Text("\(appState.healthScore)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(MacBroomTheme.animationSpring, value: appState.healthScore)
                    
                    Text(L.healthScore(lang))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                }
            }
            
            // Status Info
            VStack(alignment: .leading, spacing: 8) {
                Text(statusMessage)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.healthScore >= 70 ? MacBroomTheme.success : MacBroomTheme.warning)
                        .frame(width: 6, height: 6)
                    Text(appState.healthScore >= 70 ? "System Healthy" : "Needs Attention")
                        .font(.system(size: 11))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                }
                
                Text("Cleaned: \(cleanedGB)")
                    .font(.system(size: 11))
                    .foregroundStyle(MacBroomTheme.textMuted)
            }
            
            Spacer()
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - CPU Card
    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(icon: "cpu", title: "CPU", color: MacBroomTheme.accent)
            
            miniStat(icon: "gauge.medium", label: "Load", value: String(format: "%.0f%%", appState.cpuUsage * 100))
            miniStat(icon: "thermometer.medium", label: "Temp", value: appState.cpuTemperature >= 0 ? String(format: "%.0f°C", appState.cpuTemperature) : "N/A")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    // MARK: - RAM Card
    private var ramCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(icon: "memorychip", title: "RAM", color: MacBroomTheme.success)
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", ramUsedGB))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text("GB")
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                Spacer()
                Text("/ 16 GB")
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textMuted)
            }
            
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MacBroomTheme.success)
                        .frame(width: geo.size.width * CGFloat(min(appState.ramUsage, 1.0) * 0.7))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MacBroomTheme.success.opacity(0.35))
                        .frame(width: geo.size.width * CGFloat(min(appState.ramUsage, 1.0) * 0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                }
            }
            .frame(height: 5)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    // MARK: - Storage Card
    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(icon: "internaldrive", title: "Macintosh HD", color: MacBroomTheme.warning)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                    
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MacBroomTheme.accent)
                            .frame(width: geo.size.width * CGFloat(storagePercent * 0.35))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MacBroomTheme.accentLight)
                            .frame(width: geo.size.width * CGFloat(storagePercent * 0.40))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MacBroomTheme.accentLight.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(storagePercent * 0.25))
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 7)
            
            HStack {
                Text(String(format: "%.1f GB", usedGB))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                Text(" of ")
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Text(String(format: "%.0f GB", totalGB))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textMuted)
                
                Spacer()
                
                Text(String(format: "%.0f%%", storagePercent * 100))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(storagePercent > 0.85 ? MacBroomTheme.warning : MacBroomTheme.accent)
            }
        }
        .padding(14)
        .background(cardBackground)
    }
    
    // MARK: - Network Card
    private var networkCard: some View {
        HStack(spacing: 0) {
            networkItem(icon: "arrow.up", label: "Upload", value: formatBytes(appState.networkUpload), color: MacBroomTheme.accent)
            
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: 28)
            
            networkItem(icon: "arrow.down", label: "Download", value: formatBytes(appState.networkDownload), color: MacBroomTheme.success)
        }
        .padding(14)
        .background(cardBackground)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.quickActions(lang))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MacBroomTheme.textPrimary)
            
            HStack(spacing: 10) {
                QuickActionCard(
                    icon: "sparkles",
                    title: L.smartClean(lang),
                    subtitle: L.scanCleanJunk(lang),
                    gradient: MacBroomTheme.accentGradient,
                    index: 0,
                    isVisible: isVisible
                ) {
                    withAnimation(MacBroomTheme.animationSpring) {
                        appState.selectedPage = .smartClean
                    }
                }
                
                QuickActionCard(
                    icon: "archivebox.fill",
                    title: L.apps(lang),
                    subtitle: L.removeApps(lang),
                    gradient: LinearGradient(
                        colors: [Color(red: 1.0, green: 0.55, blue: 0.15), Color(red: 1.0, green: 0.75, blue: 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    index: 1,
                    isVisible: isVisible
                ) {
                    withAnimation(MacBroomTheme.animationSpring) {
                        appState.selectedPage = .appUninstaller
                    }
                }
                
                QuickActionCard(
                    icon: "chart.bar.fill",
                    title: L.monitor(lang),
                    subtitle: L.realtimePerf(lang),
                    gradient: LinearGradient(
                        colors: [Color(red: 0.50, green: 0.25, blue: 0.95), Color(red: 0.30, green: 0.50, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    index: 2,
                    isVisible: isVisible
                ) {
                    withAnimation(MacBroomTheme.animationSpring) {
                        appState.selectedPage = .systemMonitor
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
    
    private func cardHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MacBroomTheme.textSecondary)
        }
    }
    
    private func miniStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(MacBroomTheme.textMuted)
                .frame(width: 11)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(MacBroomTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(MacBroomTheme.textPrimary)
        }
    }
    
    private func networkItem(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statusMessage: String {
        switch appState.healthScore {
        case 80...100: return L.greatShape(lang)
        case 60..<80: return L.cleaningRecommended(lang)
        case 40..<60: return L.needsAttention(lang)
        default: return L.critical(lang)
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B/s" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB/s", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB/s", mb)
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    let index: Int
    let isVisible: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(gradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: MacBroomTheme.accent.opacity(0.3), radius: isHovered ? 8 : 4, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                    .fill(Color.white.opacity(isHovered ? 0.06 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(isHovered ? 0.12 : 0.05), .white.opacity(0.01)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(MacBroomTheme.animationFast, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .staggered(index: index + 4, isVisible: isVisible)
    }
}
