import SwiftUI

// MARK: - Smart Clean States
enum SmartCleanState {
    case idle        // First time — show scan prompt
    case scanning    // Scanning in progress
    case results     // Show scan results
    case cleaning    // Cleaning in progress
    case done        // Cleaning finished
}

struct SmartCleanView: View {
    @StateObject private var viewModel = SmartCleanViewModel()
    @State private var includeBrowserData = false
    @State private var state: SmartCleanState = .idle
    @State private var scanProgress: CGFloat = 0
    @State private var cleanProgress: CGFloat = 0
    @State private var cleaningBytes: Int64 = 0
    @State private var appearAnimation = false
    @State private var idleIconScale: CGFloat = 0.01
    @State private var idleRingRotation: Double = 0
    @State private var idleRing2Rotation: Double = 0
    @State private var doneCheckScale: CGFloat = 0
    @State private var particles: [CleanParticle] = []
    @EnvironmentObject var appState: AppState
    
    private var lang: AppLanguage { appState.currentLanguage }
    
    private var totalCleanable: String {
        ByteCountFormatter.string(fromByteCount: viewModel.totalCleanableBytes, countStyle: .file)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            
            ZStack {
                switch state {
                case .idle:
                    idleView
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
                case .cleaning:
                    cleaningView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9)),
                            removal: .opacity.combined(with: .scale(scale: 1.1))
                        ))
                case .done:
                    doneView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.5)),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: state)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                    idleIconScale = 1.0
                    appearAnimation = true
                }
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                idleRingRotation = 360
            }
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                idleRing2Rotation = -360
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.smartClean(lang))
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
        case .idle:
            VStack(spacing: 8) {
                Toggle(isOn: $includeBrowserData) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                        Text("Include Browser Data")
                            .font(.system(size: 12))
                    }
                }
                .toggleStyle(.checkbox)
                
                glassScanButton
            }
            
        case .results:
            HStack(spacing: 10) {
                glassScanButton
                
                cleanButton
            }
            
        case .done:
            glassButton(title: "Scan Again", icon: "arrow.countercockwise", color: MacBroomTheme.accent, isOutlined: true) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    state = .idle
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    private var headerSubtitle: String {
        switch state {
        case .idle: return "Scan your Mac for junk files"
        case .scanning: return "Looking for files to clean..."
        case .results: return "Review and select files to clean"
        case .cleaning: return "Cleaning in progress..."
        case .done: return "Cleaning complete!"
        }
    }
    
    // MARK: - Glass Button Components
    private var glassScanButton: some View {
        glassButton(title: "Scan Now", icon: "magnifyingglass", color: MacBroomTheme.accent) {
            startScan()
        }
    }
    
    private var cleanButton: some View {
        let isEnabled = !viewModel.selectedFileIDs.isEmpty
        return glassButton(
            title: "Clean (\(totalCleanable))",
            icon: "trash.fill",
            color: .orange,
            isDestructive: true,
            isDisabled: !isEnabled
        ) {
            if appState.licenseManager.requiresActivation() {
                appState.licenseManager.requestActivation()
                return
            }
            startCleaning()
        }
    }
    
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
    
    // MARK: - Idle State — Immersive Hero
    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack {
                // Outer ring — slow rotation
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.teal.opacity(0.0), .teal.opacity(0.15), .teal.opacity(0.0)],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(idleRingRotation))
                
                // Middle ring — reverse rotation
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, MacBroomTheme.accentLight.opacity(0.1), .clear],
                            center: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(idleRing2Rotation))
                
                // Dashed orbit
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 8]))
                    .foregroundStyle(MacBroomTheme.accent.opacity(0.08))
                    .frame(width: 280, height: 280)
                
                // Floating dots on orbit (static decoration)
                ForEach(0..<4, id: \.self) { i in
                    let angle = Double(i) * Double.pi / 2
                    Circle()
                        .fill(MacBroomTheme.accent.opacity(0.3))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: 120 * CGFloat(cos(angle)),
                            y: 120 * CGFloat(sin(angle))
                        )
                }
                
                // Glow center
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MacBroomTheme.accent.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                // Main icon with scale animation
                ZStack {
                    // Hexagon backdrop
                    HexagonShape()
                        .fill(
                            LinearGradient(
                                colors: [MacBroomTheme.accent.opacity(0.12), MacBroomTheme.accent.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            HexagonShape()
                                .stroke(MacBroomTheme.accent.opacity(0.15), lineWidth: 1)
                                .frame(width: 100, height: 100)
                        )
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [MacBroomTheme.accentLight, MacBroomTheme.accent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(idleIconScale)
            }
            .padding(.bottom, 32)
            
            VStack(spacing: 8) {
                Text(L.readyToClean(lang))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)
                
                Text(L.readyToCleanDesc(lang))
                    .font(.system(size: 14))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 80)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appearAnimation)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scanning — Multi-ring Progress
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
                
                // Glow tip at progress end
                Circle()
                    .fill(MacBroomTheme.accent)
                    .frame(width: 10, height: 10)
                    .blur(radius: 6)
                    .offset(
                        x: 80 * CGFloat(cos(2 * .pi * Double(scanProgress) - .pi / 2)),
                        y: 80 * CGFloat(sin(2 * .pi * Double(scanProgress) - .pi / 2))
                    )
                    .opacity(scanProgress > 0.02 ? 0.8 : 0)
                
                // Inner ring — spinning scan indicator
                Circle()
                    .trim(from: 0, to: 0.15)
                    .stroke(MacBroomTheme.accentLight.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(idleRingRotation))
                
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
                
                // Animated dots
                ScanDotsAnimation()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results
    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    safetyLegend
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    if !viewModel.safeItems.isEmpty {
                        resultSection(
                            icon: "checkmark.circle.fill",
                            title: "Safe to Delete",
                            subtitle: "Can be removed without any issues",
                            color: .green,
                            items: viewModel.safeItems
                        )
                    }
                    
                    if !viewModel.cautionItems.isEmpty {
                        resultSection(
                            icon: "exclamationmark.triangle.fill",
                            title: "Use Caution",
                            subtitle: "May reset app preferences or data",
                            color: .orange,
                            items: viewModel.cautionItems
                        )
                    }
                    
                    if !viewModel.unsafeItems.isEmpty {
                        resultSection(
                            icon: "xmark.shield.fill",
                            title: "Protected",
                            subtitle: "Required by system — cannot be deleted",
                            color: .red,
                            items: viewModel.unsafeItems
                        )
                    }
                }
                .padding(.bottom, 20)
            }
            
            // Bottom bar
            if !viewModel.selectedFileIDs.isEmpty {
                Divider().opacity(0.3)
                
                HStack {
                    Button("Select All Safe") { viewModel.selectAllSafe() }
                        .buttonStyle(.plain)
                        .foregroundStyle(MacBroomTheme.accent)
                        .font(.system(size: 13))
                    
                    Button("Deselect All") { viewModel.deselectAll() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    Text("\(totalCleanable) selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Cleaning — Epic Progress
    private var cleaningView: some View {
        VStack(spacing: 36) {
            Spacer()
            
            ZStack {
                // Particle effects
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .offset(x: p.x, y: p.y)
                        .opacity(p.opacity)
                        .blur(radius: 1)
                }
                
                // Outer glow ring
                Circle()
                    .stroke(
                        RadialGradient(
                            colors: [.orange.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 80,
                            endRadius: 120
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 220, height: 220)
                
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 10)
                    .frame(width: 170, height: 170)
                
                // Progress arc — gradient
                Circle()
                    .trim(from: 0, to: Double(cleanProgress))
                    .stroke(
                        AngularGradient(
                            colors: [.orange, .red, .orange],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .orange.opacity(0.4), radius: 12)
                
                // Animated trail dots
                ForEach(0..<3) { i in
                    let trailProgress = max(0, Double(cleanProgress) - Double(i) * 0.03)
                    Circle()
                        .fill(.white.opacity(0.5 - Double(i) * 0.15))
                        .frame(width: 4 - CGFloat(i), height: 4 - CGFloat(i))
                        .offset(
                            x: 85 * CGFloat(cos(2 * .pi * trailProgress - .pi / 2)),
                            y: 85 * CGFloat(sin(2 * .pi * trailProgress - .pi / 2))
                        )
                        .opacity(cleanProgress > 0.05 ? 1 : 0)
                }
                
                // Center content
                VStack(spacing: 6) {
                    Text(String(format: "%.0f%%", cleanProgress * 100))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())
                    
                    Text("Cleaning")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                        .tracking(2)
                }
            }
            
            // Bytes cleaned
            VStack(spacing: 12) {
                Text(ByteCountFormatter.string(fromByteCount: cleaningBytes, countStyle: .file))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                    .contentTransition(.numericText())
                
                // Linear progress bar with shimmer
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(cleanProgress), height: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.3), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 30, height: 6)
                                    .offset(x: geo.size.width * CGFloat(cleanProgress) - 30)
                                    .opacity(cleanProgress > 0 && cleanProgress < 1 ? 1 : 0)
                            )
                    }
                }
                .frame(width: 260, height: 6)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Done — Celebration
    private var doneView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                // Celebration particles
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .offset(x: p.x, y: p.y)
                        .opacity(p.opacity)
                }
                
                // Outer expanding ring
                Circle()
                    .stroke(MacBroomTheme.success.opacity(0.1), lineWidth: 2)
                    .frame(width: 200, height: 200)
                
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MacBroomTheme.success.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 180, height: 180)
                
                // Success hexagon
                HexagonShape()
                    .fill(
                        LinearGradient(
                            colors: [MacBroomTheme.success.opacity(0.15), MacBroomTheme.success.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        HexagonShape()
                            .stroke(MacBroomTheme.success.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 120, height: 120)
                    )
                
                // Checkmark with scale bounce
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(MacBroomTheme.success)
                    .scaleEffect(doneCheckScale)
                    .shadow(color: MacBroomTheme.success.opacity(0.5), radius: 15)
            }
            .onAppear {
                // Bounce in checkmark
                withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) {
                    doneCheckScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        doneCheckScale = 1.0
                    }
                }
                // Spawn celebration particles
                spawnCelebrationParticles()
            }
            
            VStack(spacing: 8) {
                Text(L.allClean(lang))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                HStack(spacing: 4) {
                    Text(L.freedUp(lang))
                    Text(ByteCountFormatter.string(fromByteCount: viewModel.cleanedBytes, countStyle: .file))
                        .foregroundStyle(MacBroomTheme.success)
                        .fontWeight(.bold)
                    Text(L.ofSpace(lang))
                }
                .font(.system(size: 16))
                .foregroundStyle(MacBroomTheme.textSecondary)
                
                Text(L.runningSmoother(lang))
                    .font(.system(size: 13))
                    .foregroundStyle(MacBroomTheme.textMuted)
                    .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Section Helpers
    private func resultSection(icon: String, title: String, subtitle: String, color: Color, items: [CleanableItem]) -> some View {
        VStack(spacing: 10) {
            SectionHeader(icon: icon, title: title, subtitle: subtitle, color: color)
                .padding(.horizontal, 24)
            
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ExpandableCleanTile(result: item, viewModel: viewModel)
                    .staggered(index: index, isVisible: true)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var safetyLegend: some View {
        HStack(spacing: 20) {
            safetyDot(color: .green, text: "Safe to delete")
            safetyDot(color: .orange, text: "May reset settings")
            safetyDot(color: .red, text: "Protected")
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    private func safetyDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Particle System
    private func spawnCelebrationParticles() {
        let colors: [Color] = [.green, .teal, .blue, .yellow, .orange, MacBroomTheme.accentLight]
        for i in 0..<20 {
            let angle = Double.random(in: 0...2 * .pi)
            let distance = CGFloat.random(in: 40...120)
            let particle = CleanParticle(
                x: 0, y: 0,
                targetX: distance * CGFloat(cos(angle)),
                targetY: distance * CGFloat(sin(angle)),
                size: CGFloat.random(in: 2...5),
                color: colors.randomElement()!,
                opacity: 0,
                delay: Double(i) * 0.03
            )
            particles.append(particle)
        }
        
        // Animate them outward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
                for i in particles.indices {
                    particles[i].x = particles[i].targetX
                    particles[i].y = particles[i].targetY
                    particles[i].opacity = 0.8
                }
            }
        }
        
        // Fade them out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                for i in particles.indices {
                    particles[i].opacity = 0
                }
            }
        }
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            particles = []
        }
    }
    
    private func spawnCleaningParticle() {
        let angle = Double.random(in: 0...2 * .pi)
        let p = CleanParticle(
            x: 0, y: 0,
            targetX: CGFloat.random(in: -100...100),
            targetY: CGFloat.random(in: -100...100),
            size: CGFloat.random(in: 1...3),
            color: [Color.orange, .red, .yellow].randomElement()!,
            opacity: 0,
            delay: 0
        )
        particles.append(p)
        withAnimation(.easeOut(duration: 1.5)) {
            if let idx = particles.firstIndex(where: { $0.id == p.id }) {
                particles[idx].x = p.targetX
                particles[idx].y = p.targetY
                particles[idx].opacity = 0.6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                if let idx = particles.firstIndex(where: { $0.id == p.id }) {
                    particles[idx].opacity = 0
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            particles.removeAll { $0.id == p.id }
        }
    }
    
    // MARK: - Actions
    private func startScan() {
        scanProgress = 0
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            state = .scanning
        }
        
        // Simulate progressive scan for visual
        func tickScanProgress() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if state == .scanning && scanProgress < 0.95 {
                    let increment = CGFloat.random(in: 0.01...0.04)
                    withAnimation(.easeOut(duration: 0.15)) {
                        scanProgress = min(scanProgress + increment, 0.95)
                    }
                    tickScanProgress()
                }
            }
        }
        tickScanProgress()
        
        viewModel.startScan(includeBrowserData: includeBrowserData) { hasResults in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scanProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    state = hasResults ? .results : .idle
                }
            }
        }
    }
    
    private func startCleaning() {
        let totalFiles = viewModel.selectedFileIDs.count
        guard totalFiles > 0 else { return }
        
        particles = []
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            state = .cleaning
            cleanProgress = 0
            cleaningBytes = 0
        }
        
        // Spawn particles during cleaning
        func spawnParticleLoop() {
            guard state == .cleaning else { return }
            spawnCleaningParticle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                spawnParticleLoop()
            }
        }
        spawnParticleLoop()
        
        viewModel.cleanSelectedWithProgress { progress, bytesCleaned in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cleanProgress = progress
                cleaningBytes = bytesCleaned
            }
        } completion: { totalCleaned in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                particles = []
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    viewModel.cleanedBytes = totalCleaned
                    state = .done
                }
            }
        }
    }
}

// MARK: - Particle Model
struct CleanParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
    let delay: Double
}

// MARK: - Hexagon Shape
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 - .pi / 6
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Scan Dots Animation
struct ScanDotsAnimation: View {
    @State private var activeDot = 0
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(MacBroomTheme.accent)
                    .frame(width: 5, height: 5)
                    .scaleEffect(activeDot == i ? 1.4 : 0.7)
                    .opacity(activeDot == i ? 1 : 0.3)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: activeDot)
            }
        }
        .onReceive(timer) { _ in
            activeDot = (activeDot + 1) % 3
        }
    }
}
