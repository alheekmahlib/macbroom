import SwiftUI

// MARK: - Disk Analyzer States
enum DiskAnalyzerState {
    case selectTarget   // Choose disk/folder to scan
    case scanning       // Scan in progress
    case results        // Show scan results tree
}

// MARK: - Disk Volume Model
struct DiskVolume: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let totalBytes: Int64
    let usedBytes: Int64
    let availableBytes: Int64
    let isStartupDisk: Bool
    let icon: String
    
    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    var totalString: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    var usedString: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    var availableString: String {
        ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
    }
}

// MARK: - Disk Analyzer View
struct DiskAnalyzerView: View {
    @StateObject private var viewModel = DiskAnalyzerViewModel()
    @EnvironmentObject var appState: AppState
    @State private var state: DiskAnalyzerState = .selectTarget
    @State private var scanProgress: CGFloat = 0
    @State private var appearAnimation = false
    @State private var ringRotation: Double = 0
    @State private var ring2Rotation: Double = 0
    @State private var selectedVolume: DiskVolume?
    @State private var hoveredItemID: UUID? = nil
    @State private var navigationPath: [DiskItem] = []
    
    private var lang: AppLanguage { appState.currentLanguage }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            
            ZStack {
                switch state {
                case .selectTarget:
                    selectTargetView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))
                case .scanning:
                    scanningView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                case .results:
                    resultsView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: state)
        .alert("Delete Result", isPresented: $showDeleteAlert, presenting: deleteMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        }
        .onAppear {
            viewModel.loadVolumes()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                    appearAnimation = true
                }
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                ring2Rotation = -360
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Disk Analyzer")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text(headerSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: headerSubtitle)
            }
            Spacer()
            
            headerActions
        }
        .padding(24)
    }
    
    @ViewBuilder
    private var headerActions: some View {
        switch state {
        case .selectTarget:
            EmptyView()
            
        case .scanning:
            EmptyView()
            
        case .results:
            HStack(spacing: 10) {
                glassButton(
                    title: "Scan Again",
                    icon: "arrow.countercockwise",
                    color: MacBroomTheme.accent,
                    isOutlined: true
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        state = .selectTarget
                    }
                }
                
                if !viewModel.selectedItems.isEmpty {
                    glassButton(
                        title: "Delete (\(viewModel.totalSelectedSizeString))",
                        icon: "trash.fill",
                        color: .orange,
                        isDestructive: true
                    ) {
                        if appState.licenseManager.requiresActivation() {
                            appState.licenseManager.requestActivation()
                            return
                        }
                        performDelete()
                    }
                }
            }
        }
    }
    
    private var headerSubtitle: String {
        switch state {
        case .selectTarget: return "Select a disk or folder to analyze"
        case .scanning: return "Analyzing disk usage..."
        case .results: return buildBreadcrumb()
        }
    }
    
    private func buildBreadcrumb() -> String {
        if navigationPath.isEmpty {
            return "Scan complete — \(viewModel.rootItems.count) items found"
        }
        return navigationPath.map { $0.name }.joined(separator: " › ")
    }
    
    // MARK: - Glass Button
    private func glassButton(
        title: String,
        icon: String,
        color: Color,
        isDestructive: Bool = false,
        isOutlined: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isOutlined ? color : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isOutlined {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.5), lineWidth: 1.5)
                    } else if isDestructive {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: isDisabled ? [.gray.opacity(0.3), .gray.opacity(0.2)] : [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: isDisabled ? .clear : .orange.opacity(0.3), radius: 8, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: color.opacity(0.3), radius: 8, y: 4)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
    
    // MARK: - Select Target View
    private var selectTargetView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Disk volumes section
                    if !viewModel.volumes.isEmpty {
                        SectionHeader(
                            icon: "internaldrive.fill",
                            title: "Disks",
                            subtitle: "Select a disk to scan",
                            color: MacBroomTheme.accent
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        ForEach(Array(viewModel.volumes.enumerated()), id: \.element.id) { index, volume in
                            volumeCard(volume)
                                .staggered(index: index, isVisible: appearAnimation)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Quick folders section
                    SectionHeader(
                        icon: "folder.fill",
                        title: "Quick Scan",
                        subtitle: "Common locations to analyze",
                        color: .teal
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        quickFolderCard(
                            icon: "house.fill",
                            name: "Home",
                            path: NSHomeDirectory(),
                            color: MacBroomTheme.accent,
                            index: 0
                        )
                        quickFolderCard(
                            icon: "doc.fill",
                            name: "Documents",
                            path: NSHomeDirectory() + "/Documents",
                            color: .blue,
                            index: 1
                        )
                        quickFolderCard(
                            icon: "arrow.down.circle.fill",
                            name: "Downloads",
                            path: NSHomeDirectory() + "/Downloads",
                            color: .green,
                            index: 2
                        )
                        quickFolderCard(
                            icon: "desktopcomputer",
                            name: "Desktop",
                            path: NSHomeDirectory() + "/Desktop",
                            color: .purple,
                            index: 3
                        )
                        quickFolderCard(
                            icon: "photo.fill",
                            name: "Pictures",
                            path: NSHomeDirectory() + "/Pictures",
                            color: .pink,
                            index: 4
                        )
                        quickFolderCard(
                            icon: "externaldrive.fill",
                            name: "Applications",
                            path: "/Applications",
                            color: .orange,
                            index: 5
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Volume Card
    private func volumeCard(_ volume: DiskVolume) -> some View {
        let isSelected = selectedVolume?.id == volume.id
        @State var isHovered = false
        
        return Button(action: {
            selectedVolume = volume
            startScan(path: volume.path, name: volume.name)
        }) {
            HStack(spacing: 16) {
                // Disk icon with usage ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 4)
                        .frame(width: 52, height: 52)
                    
                    Circle()
                        .trim(from: 0, to: volume.usedPercent)
                        .stroke(
                            LinearGradient(
                                colors: volume.usedPercent > 0.85 ?
                                    [MacBroomTheme.warning, MacBroomTheme.danger] :
                                    [MacBroomTheme.accent, MacBroomTheme.accentLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: volume.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(MacBroomTheme.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(volume.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MacBroomTheme.textPrimary)
                        
                        if volume.isStartupDisk {
                            Text("Startup")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(MacBroomTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(MacBroomTheme.accent.opacity(0.15)))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(volume.usedString) used")
                        Text("of")
                        Text("\(volume.totalString)")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                    
                    // Usage bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.06))
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: volume.usedPercent > 0.85 ?
                                            [MacBroomTheme.warning, MacBroomTheme.danger] :
                                            [MacBroomTheme.accent, MacBroomTheme.accentLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(volume.usedPercent))
                        }
                    }
                    .frame(height: 4)
                }
                
                Spacer()
                
                // Capacity info
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", volume.usedPercent * 100))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            volume.usedPercent > 0.85 ? MacBroomTheme.danger : MacBroomTheme.textPrimary
                        )
                    
                    Text("\(volume.availableString) free")
                        .font(.system(size: 11))
                        .foregroundStyle(MacBroomTheme.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                    .fill(Color.white.opacity(isSelected ? 0.08 : (isHovered ? 0.05 : 0.02)))
                    .overlay(
                        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(isSelected ? 0.20 : (isHovered ? 0.12 : 0.04)), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1), radius: isHovered ? 8 : 3, y: isHovered ? 3 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    // MARK: - Quick Folder Card
    private func quickFolderCard(icon: String, name: String, path: String, color: Color, index: Int) -> some View {
        Button(action: {
            startScan(path: path, name: name)
        }) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.10))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(color)
                }
                
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                    .fill(Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .staggered(index: index, isVisible: appearAnimation)
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(MacBroomTheme.accent.opacity(0.06), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(scanProgress > 0 ? 1.0 : 0.8)
                    .opacity(scanProgress > 0 ? 1 : 0.5)
                
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 8)
                    .frame(width: 160, height: 160)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: Double(scanProgress))
                    .stroke(
                        AngularGradient(
                            colors: [MacBroomTheme.accent, MacBroomTheme.accentLight, MacBroomTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                // Glow tip
                Circle()
                    .fill(MacBroomTheme.accent)
                    .frame(width: 10, height: 10)
                    .blur(radius: 6)
                    .offset(
                        x: 80 * CGFloat(cos(2 * .pi * Double(scanProgress) - .pi / 2)),
                        y: 80 * CGFloat(sin(2 * .pi * Double(scanProgress) - .pi / 2))
                    )
                    .opacity(scanProgress > 0.02 ? 0.8 : 0)
                
                // Inner ring — spinning
                Circle()
                    .trim(from: 0, to: 0.15)
                    .stroke(MacBroomTheme.accentLight.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(ringRotation))
                
                // Center content
                VStack(spacing: 6) {
                    Text(String(format: "%.0f%%", scanProgress * 100))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                        .contentTransition(.numericText())
                    
                    Text("Scanning")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MacBroomTheme.accent)
                        .tracking(1.5)
                }
            }
            
            // Path display
            VStack(spacing: 10) {
                Text(viewModel.currentScanPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MacBroomTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 60)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.currentScanPath)
                
                ScanDotsAnimation()
            }
            
            // Found items counter
            if !viewModel.rootItems.isEmpty {
                Text("\(viewModel.rootItems.count) items found — \(totalScannedSize)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                    .transition(.opacity)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var totalScannedSize: String {
        let total = viewModel.rootItems.reduce(Int64(0)) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Top summary bar
            resultSummaryBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
            
            Divider().opacity(0.2)
                .padding(.vertical, 8)
            
            // Navigation breadcrumb
            if !navigationPath.isEmpty {
                breadcrumbBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
            
            // Files list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    let items = currentDisplayItems
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        diskItemRow(item, index: index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Bottom action bar
            if !viewModel.selectedItems.isEmpty {
                Divider().opacity(0.3)
                
                HStack {
                    Button("Select All") { viewModel.selectAll() }
                        .buttonStyle(.plain)
                        .foregroundStyle(MacBroomTheme.accent)
                        .font(.system(size: 13))
                    
                    Button("Deselect All") { viewModel.deselectAll() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    Text("\(viewModel.selectedItems.count) selected — \(viewModel.totalSelectedSizeString)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Result Summary
    private var resultSummaryBar: some View {
        let loadedItems = viewModel.rootItems.filter { $0.isSizeLoaded }
        let totalSize = loadedItems.reduce(Int64(0)) { $0 + $1.size }
        let totalFiles = viewModel.rootItems.reduce(0) { $0 + $1.fileCount }
        
        return HStack(spacing: 20) {
            // Total size
            summaryStat(
                icon: "externaldrive.fill",
                label: "Total Size",
                value: ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file),
                color: MacBroomTheme.accent
            )
            
            // Items count
            summaryStat(
                icon: "number",
                label: "Items",
                value: "\(viewModel.rootItems.count)",
                color: .teal
            )
            
            // Files count
            summaryStat(
                icon: "doc.fill",
                label: "Files",
                value: "\(totalFiles)",
                color: .purple
            )
            
            Spacer()
            
            // Size distribution mini bar
            if !viewModel.rootItems.isEmpty {
                sizeDistributionBar
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    private func summaryStat(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(MacBroomTheme.textMuted)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
            }
        }
    }
    
    // MARK: - Size Distribution Bar
    private var sizeDistributionBar: some View {
        let loadedItems = viewModel.rootItems.filter { $0.isSizeLoaded }
        let totalSize = loadedItems.reduce(Int64(0)) { $0 + $1.size }
        let colors: [Color] = [.blue, .teal, .green, .yellow, .orange, .red, .purple, .pink, .cyan]
        
        return VStack(alignment: .trailing, spacing: 4) {
            Text("Distribution")
                .font(.system(size: 9))
                .foregroundStyle(MacBroomTheme.textMuted)
            
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(Array(loadedItems.prefix(9).enumerated()), id: \.element.id) { index, item in
                        let ratio = totalSize > 0 ? CGFloat(item.size) / CGFloat(totalSize) : 0
                        RoundedRectangle(cornerRadius: 1)
                            .fill(colors[index % colors.count].opacity(0.7))
                            .frame(width: max(1, geo.size.width * ratio))
                    }
                }
            }
            .frame(width: 140, height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
    
    // MARK: - Breadcrumb Bar
    private var breadcrumbBar: some View {
        HStack(spacing: 4) {
            // Root button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    navigationPath = []
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                    Text("Root")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(navigationPath.isEmpty ? MacBroomTheme.textPrimary : MacBroomTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(navigationPath.isEmpty ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
                )
            }
            .buttonStyle(.plain)
            
            ForEach(Array(navigationPath.enumerated()), id: \.element.id) { index, item in
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(MacBroomTheme.textMuted)
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        navigationPath = Array(navigationPath.prefix(index + 1))
                    }
                }) {
                    Text(item.name)
                        .font(.system(size: 11, weight: index == navigationPath.count - 1 ? .semibold : .medium))
                        .foregroundStyle(index == navigationPath.count - 1 ? MacBroomTheme.textPrimary : MacBroomTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(index == navigationPath.count - 1 ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
                        )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Current Display Items
    private var currentDisplayItems: [DiskItem] {
        if navigationPath.isEmpty {
            return viewModel.rootItems
        }
        return navigationPath.last?.children ?? []
    }
    
    // MARK: - Disk Item Row
    private func diskItemRow(_ item: DiskItem, index: Int) -> some View {
        let isHovered = hoveredItemID == item.id
        let isSelected = viewModel.selectedItems.contains(item.id)
        let loadedItems = viewModel.rootItems.filter { $0.isSizeLoaded }
        let totalSize = loadedItems.reduce(Int64(0)) { $0 + $1.size }
        let sizeRatio = totalSize > 0 && item.isSizeLoaded ? CGFloat(item.size) / CGFloat(totalSize) : 0
        
        return HStack(spacing: 12) {
            // Selection checkbox
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.toggleSelect(item)
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? MacBroomTheme.accent : Color.white.opacity(0.06))
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        item.isDirectory ?
                        MacBroomTheme.accent.opacity(0.10) :
                        Color.gray.opacity(0.06)
                    )
                    .frame(width: 34, height: 34)
                
                Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.name))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isDirectory ? MacBroomTheme.accent : .gray)
            }
            
            // Name + bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                        .lineLimit(1)
                    
                    if item.isDirectory && item.isSizeLoaded {
                        Text("\(item.children.count) items")
                            .font(.system(size: 10))
                            .foregroundStyle(MacBroomTheme.textMuted)
                    }
                    
                    // Loading indicator for size
                    if item.isDirectory && !item.isSizeLoaded {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // Size bar (only show when size is loaded)
                if item.isSizeLoaded {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.04))
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    sizeBarColor(for: item)
                                        .opacity(0.6)
                                )
                                .frame(width: geo.size.width * min(CGFloat(sizeRatio * 10), 1.0))
                        }
                    }
                    .frame(height: 3)
                } else {
                    // Shimmer placeholder for loading
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.04))
                    }
                    .frame(height: 3)
                }
            }
            
            Spacer()
            
            // Size
            if item.isSizeLoaded {
                Text(item.sizeString)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                    .frame(width: 80, alignment: .trailing)
                
                // Percentage
                Text(String(format: "%.1f%%", Double(item.size) / Double(max(1, totalSize)) * 100))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textMuted)
                    .frame(width: 45, alignment: .trailing)
            } else {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 60, height: 12)
                    .frame(width: 125, alignment: .trailing)
            }
            
            // Navigate button for directories
            if item.isDirectory {
                if loadingFolderID == item.id {
                    // Loading spinner
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 24, height: 24)
                } else {
                    Button(action: {
                        navigateInto(item)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MacBroomTheme.textMuted)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.03))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected ? MacBroomTheme.accent.opacity(0.08) :
                    (isHovered ? Color.white.opacity(0.04) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if item.isDirectory {
                navigateInto(item)
            }
        }
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : nil
        }
        .staggered(index: index, isVisible: true)
    }
    
    // MARK: - Helpers
    private func sizeBarColor(for item: DiskItem) -> Color {
        let loadedItems = viewModel.rootItems.filter { $0.isSizeLoaded }
        let totalSize = loadedItems.reduce(Int64(0)) { $0 + $1.size }
        let ratio = totalSize > 0 && item.isSizeLoaded ? Double(item.size) / Double(totalSize) : 0
        
        if ratio > 0.3 { return MacBroomTheme.danger }
        if ratio > 0.15 { return MacBroomTheme.warning }
        if ratio > 0.05 { return MacBroomTheme.accent }
        return .teal
    }
    
    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "pdf": return "doc.fill"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "swift", "js", "py", "ts", "html", "css": return "chevron.left.forwardslash.chevron.right"
        case "dmg", "pkg", "app": return "app.fill"
        case "json", "xml", "yaml", "plist": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    // MARK: - Navigation
    @State private var loadingFolderID: UUID? = nil
    
    private func navigateInto(_ item: DiskItem) {
        if item.isDirectory {
            // Use cached result if available — INSTANT navigation!
            let children = viewModel.loadChildren(for: item.url.path)
            
            // Flatten children into allItemsFlat so selection/deletion works
            viewModel.flattenItems(children)
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                navigationPath.append(DiskItem(
                    url: item.url,
                    name: item.name,
                    size: item.size,
                    isDirectory: item.isDirectory,
                    children: children,
                    isSizeLoaded: item.isSizeLoaded
                ))
            }
        }
    }
    
    private func updateItemChildren(_ target: DiskItem, newChildren: [DiskItem]) {
        // Rebuild rootItems with updated children
        viewModel.rootItems = viewModel.rootItems.map { rootItem in
            rebuildItem(rootItem, target: target, newChildren: newChildren)
        }
        // Also rebuild navigation path
        navigationPath = navigationPath.map { pathItem in
            rebuildItem(pathItem, target: target, newChildren: newChildren)
        }
        viewModel.flattenAllItems()
    }
    
    private func rebuildItem(_ item: DiskItem, target: DiskItem, newChildren: [DiskItem]) -> DiskItem {
        if item.id == target.id {
            return DiskItem(url: item.url, name: item.name, size: item.size, isDirectory: item.isDirectory, children: newChildren)
        }
        return DiskItem(
            url: item.url,
            name: item.name,
            size: item.size,
            isDirectory: item.isDirectory,
            children: item.children.map { rebuildItem($0, target: target, newChildren: newChildren) }
        )
    }
    
    // MARK: - Actions
    private func startScan(path: String, name: String) {
        scanProgress = 0
        navigationPath = []
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            state = .scanning
        }
        
        // Sync real progress from ViewModel
        func tickRealProgress() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if state == .scanning {
                    // Use ViewModel's real scanProgress (driven by files scanned)
                    withAnimation(.easeOut(duration: 0.15)) {
                        scanProgress = CGFloat(viewModel.scanProgress)
                    }
                    tickRealProgress()
                }
            }
        }
        tickRealProgress()
        
        viewModel.startScan(path: path) { hasResults in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scanProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    state = hasResults ? .results : .selectTarget
                }
            }
        }
    }
    
    @State private var deleteMessage: String?
    @State private var showDeleteAlert: Bool = false
    
    private func performDelete() {
        let currentPath: String
        if navigationPath.isEmpty {
            currentPath = selectedVolume?.path ?? "/"
        } else {
            currentPath = navigationPath.last?.url.path ?? "/"
        }
        
        let result = viewModel.deleteSelected()
        if result.deleted > 0 {
            deleteMessage = "Deleted \(result.deleted) items, freed \(ByteCountFormatter.string(fromByteCount: result.freedBytes, countStyle: .file))"
        } else if result.failed > 0 {
            deleteMessage = "Failed to delete \(result.failed) items. Make sure they are not in use."
        }
        showDeleteAlert = true
        
        // Rebuild items from cache for current path
        let freshItems = viewModel.loadChildren(for: currentPath)
        if navigationPath.isEmpty {
            viewModel.rootItems = freshItems
        } else if !navigationPath.isEmpty {
            // Update the last navigation item's children
            let lastIndex = navigationPath.count - 1
            navigationPath[lastIndex] = DiskItem(
                id: navigationPath[lastIndex].id,
                url: navigationPath[lastIndex].url,
                name: navigationPath[lastIndex].name,
                size: navigationPath[lastIndex].size,
                isDirectory: true,
                children: freshItems,
                isSizeLoaded: true
            )
        }
    }
}
