import SwiftUI

// MARK: - Menu Bar Popover Dashboard
struct MenuBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var ramViewModel = RamBoosterViewModel()
    
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
    
    private var freeGB: Double { totalGB - usedGB }
    
    private var storageSystemDataPercent: Double {
        guard totalGB > 0 else { return 0 }
        return storagePercent * 0.25
    }
    private var storageAppsPercent: Double {
        guard totalGB > 0 else { return 0 }
        return storagePercent * 0.30
    }
    private var storageDocsPercent: Double {
        guard totalGB > 0 else { return 0 }
        return storagePercent * 0.20
    }
    private var storageMailPercent: Double {
        guard totalGB > 0 else { return 0 }
        return storagePercent * 0.08
    }
    private var storageOtherUsersPercent: Double {
        guard totalGB > 0 else { return 0 }
        return storagePercent * 0.17
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // ── Top: CPU + RAM ──
            HStack(spacing: 8) {
                // CPU Card
                VStack(alignment: .leading, spacing: 6) {
                    cardHeader(icon: "cpu", title: "CPU", color: Color(red: 0.40, green: 0.55, blue: 1.0))
                    
                    miniStat(icon: "gauge.medium", label: "Load", value: String(format: "%.0f%%", appState.cpuUsage * 100))
                    miniStat(icon: "thermometer.medium", label: "Temp", value: appState.cpuTemperature >= 0 ? String(format: "%.0f°C", appState.cpuTemperature) : "N/A")
                    miniStat(icon: "fan", label: "Fan", value: "N/A")
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // RAM Card — with accurate data + Free RAM button
                VStack(alignment: .leading, spacing: 6) {
                    cardHeader(icon: "bolt.fill", title: "RAM", color: Color(red: 0.30, green: 0.78, blue: 0.55))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", ramUsedGB))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("GB")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text("/ \(totalRAMGB) GB")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    
                    // Segmented bar
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.30, green: 0.78, blue: 0.55))
                                .frame(width: geo.size.width * CGFloat(ramViewModel.memoryInfo.usagePercent))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.30, green: 0.78, blue: 0.55).opacity(0.35))
                                .frame(width: geo.size.width * CGFloat(ramViewModel.memoryInfo.freePercent))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.06))
                        }
                    }
                    .frame(height: 5)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    
                    // Mini app list (top 3 by RAM)
                    if !ramViewModel.topApps.prefix(3).isEmpty {
                        VStack(spacing: 3) {
                            ForEach(ramViewModel.topApps.prefix(3)) { app in
                                HStack(spacing: 4) {
                                    Image(systemName: app.icon)
                                        .font(.system(size: 7))
                                        .foregroundStyle(.white.opacity(0.3))
                                        .frame(width: 10)
                                    Text(app.name)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(app.rssString.replacingOccurrences(of: " GB", with: "G").replacingOccurrences(of: " MB", with: "M"))
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                    }
                    
                    // Free RAM button
                    Button(action: {
                        openAppAndNavigate(to: .ramBooster)
                        // Trigger free after a short delay so the view loads
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            ramViewModel.freeUpRAM()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text("Free RAM")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.30, green: 0.78, blue: 0.55), Color(red: 0.25, green: 0.65, blue: 0.45)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // ── Network ──
            HStack(spacing: 0) {
                networkItem(icon: "arrow.up", label: "Upload", value: formatBytes(appState.networkUpload), color: Color(red: 0.40, green: 0.55, blue: 1.0))
                
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 28)
                
                networkItem(icon: "arrow.down", label: "Download", value: formatBytes(appState.networkDownload), color: Color(red: 0.30, green: 0.78, blue: 0.55))
            }
            .padding(10)
            
            // ── Storage ──
            VStack(alignment: .leading, spacing: 6) {
                cardHeader(icon: "internaldrive", title: "Macintosh HD", color: Color(red: 1.0, green: 0.65, blue: 0.15))
                
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.25, green: 0.45, blue: 0.95))
                            .frame(width: geo.size.width * CGFloat(storageSystemDataPercent))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.40, green: 0.60, blue: 1.0))
                            .frame(width: geo.size.width * CGFloat(storageAppsPercent))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 1.0, green: 0.65, blue: 0.15))
                            .frame(width: geo.size.width * CGFloat(storageDocsPercent))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * CGFloat(storageMailPercent))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.95, green: 0.30, blue: 0.35).opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(storageOtherUsersPercent))
                        Spacer(minLength: 0)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Compact legend + Clean button
                HStack(spacing: 7) {
                    storageLegendDot(color: Color(red: 0.25, green: 0.45, blue: 0.95), label: "System")
                    storageLegendDot(color: Color(red: 0.40, green: 0.60, blue: 1.0), label: "Apps")
                    storageLegendDot(color: Color(red: 1.0, green: 0.65, blue: 0.15), label: "Docs")
                    storageLegendDot(color: Color.purple, label: "Mail")
                    storageLegendDot(color: Color(red: 0.95, green: 0.30, blue: 0.35).opacity(0.7), label: "Shared")
                    Spacer()
                    Text(String(format: "%.0f%%", storagePercent * 100))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(storagePercent > 0.85 ? Color.orange : Color(red: 0.40, green: 0.55, blue: 1.0))
                }
                
                // Clean button
                Button(action: {
                    openAppAndNavigate(to: .smartClean)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                        Text("Clean")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.40, green: 0.55, blue: 1.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            
            // ── Bottom Actions ──
            HStack(spacing: 8) {
                smallButton(icon: "arrow.clockwise") {
                    appState.refreshSystemInfo()
                    ramViewModel.refresh()
                }
                smallButton(icon: "gearshape") {
                    openAppAndNavigate(to: .settings)
                }
                
                // Quit button
                smallButton(icon: "power") {
                    // This calls applicationShouldTerminate which checks shouldReallyQuit
                    // We set it via UserDefaults as a simple cross-context signal
                    UserDefaults.standard.set(true, forKey: "forceQuit")
                    NSApplication.shared.terminate(nil)
                }
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    // Show main window
                    for window in NSApplication.shared.windows {
                        if !(window is NSPanel) && !window.styleMask.contains(.utilityWindow) {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                    NSApplication.shared.setActivationPolicy(.regular)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .bold))
                        Text("Open MacBroom")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.40, green: 0.55, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.13, blue: 0.28), Color(red: 0.07, green: 0.09, blue: 0.20)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            appState.refreshSystemInfo()
            ramViewModel.refresh()
        }
    }
    
    // MARK: - Computed RAM values (from accurate RamBoosterService)
    private var ramUsedGB: Double {
        Double(ramViewModel.memoryInfo.usedBytes) / 1_000_000_000
    }
    
    private var totalRAMGB: Int {
        Int(Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000)
    }
    
    // MARK: - Navigation
    private func openAppAndNavigate(to page: AppState.Page) {
        appState.selectedPage = page
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows {
            if !(window is NSPanel) && !window.styleMask.contains(.utilityWindow) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    // MARK: - Components
    private func cardHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
    
    private func miniStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 11)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
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
                    .foregroundStyle(.white.opacity(0.35))
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func smallButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
    
    private func storageLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.4))
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
