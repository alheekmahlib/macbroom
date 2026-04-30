import SwiftUI

struct RamBoosterView: View {
    @StateObject private var viewModel = RamBoosterViewModel()
    @EnvironmentObject var appState: AppState
    @State private var appearAnimation = false
    @State private var ringRotation: Double = 0
    @State private var pulseAnimation = false
    
    private var lang: AppLanguage { appState.currentLanguage }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Main ring chart + stats
                    mainMemorySection
                    
                    // Free Up button + result
                    freeUpSection
                    
                    // Apps list (grouped by app, with expandable details)
                    appsSection
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }
        }
        .background(MacBroomTheme.bgPrimary)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appearAnimation = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Up RAM")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                    
                    Text(headerSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                }
                
                Spacer()
                
                // Monitor toggle
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 6, height: 6)
                    
                    Text(viewModel.isMonitoring ? "Live" : "Paused")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MacBroomTheme.textMuted)
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.isMonitoring },
                        set: { _ in viewModel.toggleMonitoring() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(MacBroomTheme.accent)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(MacBroomTheme.bgSecondary)
    }
    
    private var headerSubtitle: String {
        if viewModel.isFreeing {
            return "Freeing memory..."
        }
        if viewModel.showFreedResult && viewModel.freedBytes > 0 {
            return "Freed \(viewModel.freedRAMString)!"
        }
        return "\(viewModel.totalRAMString) Total • \(viewModel.pressurePercent)% In Use"
    }
    
    // MARK: - Main Memory Section
    private var mainMemorySection: some View {
        HStack(spacing: 24) {
            // Ring chart
            memoryRing
                .frame(width: 180, height: 180)
            
            // Stats breakdown + pressure history
            VStack(spacing: 0) {
                // Memory breakdown
                VStack(spacing: 10) {
                    statRow(label: "Active", value: formatBytes(viewModel.memoryInfo.activeBytes), color: MacBroomTheme.accent, icon: "app.fill")
                    statRow(label: "Wired", value: formatBytes(viewModel.memoryInfo.wiredBytes), color: Color.red.opacity(0.8), icon: "lock.fill")
                    statRow(label: "Compressed", value: formatBytes(viewModel.memoryInfo.compressedBytes), color: Color.orange, icon: "arrow.down.doc.fill")
                    statRow(label: "Reclaimable", value: formatBytes(viewModel.memoryInfo.inactiveBytes), color: Color.purple, icon: "arrow.uturn.down.circle.fill")
                    statRow(label: "Free", value: formatBytes(viewModel.memoryInfo.freeBytes), color: Color.green, icon: "checkmark.circle.fill")
                }
                
                Spacer(minLength: 12)
                
                // Pressure sparkline
                if viewModel.pressureHistory.count > 2 {
                    pressureSparkline
                        .frame(height: 35)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(cardBackground)
    }
    
    // MARK: - Memory Ring
    private var memoryRing: some View {
        let total = CGFloat(max(1, viewModel.memoryInfo.totalBytes))
        let activeR = CGFloat(viewModel.memoryInfo.activeBytes) / total
        let wiredR = CGFloat(viewModel.memoryInfo.wiredBytes) / total
        let compressedR = CGFloat(viewModel.memoryInfo.compressedBytes) / total
        
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 14)
            
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [MacBroomTheme.accent.opacity(0.1), MacBroomTheme.accent.opacity(0.3)],
                        center: .center
                    ),
                    lineWidth: 1
                )
                .rotationEffect(.degrees(ringRotation))
            
            // Active (used)
            Circle()
                .trim(from: 0, to: activeR)
                .stroke(MacBroomTheme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Wired (system, used)
            Circle()
                .trim(from: activeR, to: activeR + wiredR)
                .stroke(Color.red.opacity(0.8), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Compressed (used)
            Circle()
                .trim(from: activeR + wiredR, to: activeR + wiredR + compressedR)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Center
            VStack(spacing: 2) {
                Text("\(viewModel.pressurePercent)%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                Text("In Use")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textMuted)
                
                pressureBadge
            }
        }
    }
    
    private var pressureBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(pressureColor)
                .frame(width: 5, height: 5)
            
            Text(viewModel.memoryInfo.pressureLevel.label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(pressureColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(pressureColor.opacity(0.12)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    private var pressureColor: Color {
        switch viewModel.memoryInfo.pressureLevel {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .urgent: return .red
        }
    }
    
    // MARK: - Pressure Sparkline
    private var pressureSparkline: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Pressure")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textMuted)
                
                Picker("", selection: Binding(
                    get: { viewModel.monitorInterval == 5 ? 0 : viewModel.monitorInterval == 10 ? 1 : 2 },
                    set: { viewModel.setMonitorInterval($0 == 0 ? 5 : $0 == 1 ? 10 : 30) }
                )) {
                    Text("5s").tag(0)
                    Text("10s").tag(1)
                    Text("30s").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            
            GeometryReader { geo in
                let values = viewModel.pressureHistory
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 1
                let range = max(maxVal - minVal, 0.01)
                
                // Fill
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) / CGFloat(values.count - 1) * geo.size.width
                        let y = geo.size.height - CGFloat(value - minVal) / CGFloat(range) * geo.size.height
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [MacBroomTheme.accent.opacity(0.15), MacBroomTheme.accent.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                
                // Line
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) / CGFloat(values.count - 1) * geo.size.width
                        let y = geo.size.height - CGFloat(value - minVal) / CGFloat(range) * geo.size.height
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(MacBroomTheme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
    
    // MARK: - Free Up Section
    private var freeUpSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                if appState.licenseManager.requiresActivation() {
                    appState.licenseManager.requestActivation()
                    return
                }
                viewModel.freeUpRAM()
            }) {
                HStack(spacing: 10) {
                    if viewModel.isFreeing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    
                    Text(viewModel.isFreeing ? "Freeing..." : "Free Up RAM")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                        .fill(
                            viewModel.isFreeing ?
                            LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [MacBroomTheme.accent, MacBroomTheme.accentLight], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: MacBroomTheme.accent.opacity(viewModel.isFreeing ? 0 : 0.35), radius: 12, y: 4)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isFreeing)
            
            if viewModel.showFreedResult && viewModel.freedBytes > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                    
                    Text("+\(viewModel.freedRAMString) freed")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            Text("Updated \(timeAgo(viewModel.lastMonitorUpdate))")
                .font(.system(size: 11))
                .foregroundStyle(MacBroomTheme.textMuted)
        }
        .padding(20)
        .background(cardBackground)
    }
    
    // MARK: - Apps Section
    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                    .foregroundStyle(MacBroomTheme.accent)
                
                Text("Memory Usage by App")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.topApps.count) apps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if viewModel.topApps.isEmpty {
                Text("Loading...")
                    .font(.system(size: 12))
                    .foregroundStyle(MacBroomTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                // Find max RAM for relative bar sizing
                let maxRSS = viewModel.topApps.first?.totalRSS ?? 1
                
                ForEach(viewModel.topApps) { app in
                    appRow(app: app, maxRSS: maxRSS)
                    
                    if app.id != viewModel.topApps.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.04))
                            .padding(.horizontal, 16)
                    }
                    
                    // Expanded processes
                    if viewModel.expandedAppID == app.id && app.processCount > 1 {
                        expandedProcesses(app: app)
                    }
                }
            }
        }
        .background(cardBackground)
    }
    
    private func appRow(app: AppMemoryInfo, maxRSS: UInt64) -> some View {
        Button(action: {
            if app.processCount > 1 {
                viewModel.toggleAppExpansion(app)
            }
        }) {
            HStack(spacing: 12) {
                // App icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(MacBroomTheme.accent.opacity(0.10))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: app.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MacBroomTheme.accent)
                    )
                
                // Name + process count
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                        .lineLimit(1)
                    
                    if app.processCount > 1 {
                        Text("\(app.processCount) processes")
                            .font(.system(size: 10))
                            .foregroundStyle(MacBroomTheme.textMuted)
                    }
                }
                
                Spacer()
                
                // Memory bar
                let barRatio = CGFloat(app.totalRSS) / CGFloat(max(1, maxRSS))
                GeometryReader { geo in
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.04))
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: barColor(for: app.totalRSS),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * barRatio)
                    }
                }
                .frame(width: 80, height: 6)
                
                // RAM size
                Text(app.rssString)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                    .frame(width: 65, alignment: .trailing)
                
                // Percentage
                let pct = Double(app.totalRSS) / Double(max(1, viewModel.memoryInfo.totalBytes)) * 100
                Text(String(format: "%.1f%%", pct))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textMuted)
                    .frame(width: 40, alignment: .trailing)
                
                // Expand arrow
                if app.processCount > 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MacBroomTheme.textMuted)
                        .rotationEffect(.degrees(viewModel.expandedAppID == app.id ? 90 : 0))
                        .animation(.spring(response: 0.3), value: viewModel.expandedAppID == app.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func expandedProcesses(app: AppMemoryInfo) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(app.processes.enumerated()), id: \.offset) { index, proc in
                HStack(spacing: 12) {
                    // Indent
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .frame(width: 32, height: 24)
                    
                    // Process name
                    Text(proc.name)
                        .font(.system(size: 11))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                    
                    Spacer()
                    
                    // PID
                    Text("PID \(proc.pid)")
                        .font(.system(size: 9))
                        .foregroundStyle(MacBroomTheme.textMuted)
                    
                    // Size
                    let mbStr = ByteCountFormatter.string(fromByteCount: Int64(proc.rss), countStyle: .memory)
                    Text(mbStr)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                        .frame(width: 65, alignment: .trailing)
                    
                    // Spacer to align with parent
                    if app.processCount > 1 {
                        Color.clear.frame(width: 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.02))
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Helpers
    
    private func statRow(label: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(0.12))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(color)
                )
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MacBroomTheme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(MacBroomTheme.textPrimary)
        }
    }
    
    private func barColor(for rss: UInt64) -> [Color] {
        let ratio = Double(rss) / Double(max(1, viewModel.memoryInfo.totalBytes))
        if ratio > 0.10 { return [.orange, .red] }
        if ratio > 0.05 { return [MacBroomTheme.accent, .purple] }
        return [MacBroomTheme.accent.opacity(0.7), MacBroomTheme.accent.opacity(0.4)]
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
            .fill(MacBroomTheme.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 5 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        return "\(Int(interval / 60))m ago"
    }
}
