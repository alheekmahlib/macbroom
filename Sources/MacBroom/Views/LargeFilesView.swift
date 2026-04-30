import SwiftUI

struct LargeFilesView: View {
    @StateObject private var viewModel = LargeFilesViewModel()
    @State private var appearAnimation = false
    @State private var showDeleteConfirm = false
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            
            if viewModel.isScanning {
                scanningView
                    .transition(.opacity)
            } else if !viewModel.hasScanned {
                idleView
                    .transition(.opacity)
            } else if viewModel.allFiles.isEmpty {
                emptyView
                    .transition(.opacity)
            } else {
                resultsView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isScanning)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.hasScanned)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    appearAnimation = true
                }
            }
        }
        .alert("Delete Selected Files?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                performDelete()
            }
        } message: {
            Text("\(viewModel.selectedFiles.count) files (\(viewModel.totalSelectedSizeString)) will be moved to Trash.")
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Large Files")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text(viewModel.hasScanned ? "\(viewModel.allFiles.count) large files found" : "Find and remove large files taking up space")
                    .font(.system(size: 13))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
            Spacer()
            
            if !viewModel.isScanning {
                HStack(spacing: 8) {
                    Text("Min:")
                        .font(.system(size: 12))
                        .foregroundStyle(MacBroomTheme.textMuted)
                    
                    Picker("", selection: $viewModel.minimumSizeMB) {
                        Text("50 MB").tag(50)
                        Text("100 MB").tag(100)
                        Text("250 MB").tag(250)
                        Text("500 MB").tag(500)
                        Text("1 GB").tag(1000)
                    }
                    .frame(width: 85)
                    .onChange(of: viewModel.minimumSizeMB) { _ in
                        if viewModel.hasScanned { viewModel.startScan() }
                    }
                    
                    Button(action: { viewModel.startScan() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .bold))
                            Text(viewModel.hasScanned ? "Rescan" : "Scan Now")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(MacBroomTheme.accentGradient)
                                .shadow(color: MacBroomTheme.accent.opacity(0.3), radius: 8, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
    }
    
    // MARK: - Idle
    private var idleView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().stroke(MacBroomTheme.accent.opacity(0.06), lineWidth: 1.5).frame(width: 200, height: 200)
                Circle().stroke(MacBroomTheme.accent.opacity(0.03), lineWidth: 1).frame(width: 260, height: 260)
                Circle()
                    .fill(RadialGradient(colors: [MacBroomTheme.accent.opacity(0.12), .clear], center: .center, startRadius: 20, endRadius: 80))
                    .frame(width: 140, height: 140)
                Image(systemName: "doc.badge.gearshape.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [MacBroomTheme.accentLight, MacBroomTheme.accent], startPoint: .top, endPoint: .bottom))
            }
            .scaleEffect(appearAnimation ? 1 : 0.5)
            .opacity(appearAnimation ? 1 : 0)
            
            VStack(spacing: 8) {
                Text("Find Large Files")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text("Scan your Mac to discover large files\nthat are taking up valuable disk space")
                    .font(.system(size: 14))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scanning
    private var scanningView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.04), lineWidth: 8).frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: Double(viewModel.scanProgress))
                    .stroke(
                        AngularGradient(colors: [MacBroomTheme.accent, MacBroomTheme.accentLight, MacBroomTheme.accent], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0, to: 0.15)
                    .stroke(MacBroomTheme.accentLight.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360) * 60))
                VStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").font(.system(size: 24, weight: .medium)).foregroundStyle(MacBroomTheme.accent)
                    Text("Scanning...").font(.system(size: 10, weight: .medium)).foregroundStyle(MacBroomTheme.accent).tracking(1)
                }
            }
            Text(viewModel.currentScanPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MacBroomTheme.textMuted)
                .lineLimit(1).truncationMode(.middle).padding(.horizontal, 60)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)).foregroundStyle(MacBroomTheme.success)
                .shadow(color: MacBroomTheme.success.opacity(0.3), radius: 12)
            Text("No Large Files Found").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(MacBroomTheme.textPrimary)
            Text("No files larger than \(viewModel.minimumSizeMB) MB were found").font(.system(size: 14)).foregroundStyle(MacBroomTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Category filter bar (horizontal)
            categoryBar
            
            Divider().opacity(0.2)
            
            // File list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredFiles.enumerated()), id: \.element.id) { index, file in
                        LargeFileRow(
                            file: file,
                            isSelected: viewModel.selectedFiles.contains(file.id),
                            onToggle: { viewModel.toggleFile(file.id) }
                        )
                        .staggered(index: index, isVisible: true)
                        
                        if file.id != viewModel.filteredFiles.last?.id {
                            Divider().opacity(0.08).padding(.leading, 56)
                        }
                    }
                }
                .padding(.bottom, 80) // space for bottom bar
            }
            
            // Bottom action bar
            bottomBar
        }
    }
    
    // MARK: - Category Bar
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.categoryCounts, id: \.0) { cat, count, totalSize in
                    if count > 0 || cat == .all {
                        CategoryChip(
                            category: cat,
                            count: count,
                            totalSize: totalSize,
                            isSelected: viewModel.selectedCategory == cat,
                            action: {
                                withAnimation(MacBroomTheme.animationFast) {
                                    viewModel.selectedCategory = cat
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        let hasSelection = !viewModel.selectedFiles.isEmpty
        
        return VStack(spacing: 0) {
            Divider().opacity(0.3)
            
            HStack(spacing: 16) {
                // Select actions
                Button(viewModel.selectedFiles.count == viewModel.filteredFiles.count ? "Deselect All" : "Select All") {
                    if viewModel.selectedFiles.count == viewModel.filteredFiles.count {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MacBroomTheme.accent)
                
                Text("·")
                    .foregroundStyle(MacBroomTheme.textMuted)
                
                Text("\(viewModel.filteredFiles.count) files")
                    .font(.system(size: 13))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                
                Spacer()
                
                // Selection info
                if hasSelection {
                    HStack(spacing: 6) {
                        Circle().fill(MacBroomTheme.accent).frame(width: 6, height: 6)
                        Text("\(viewModel.selectedFiles.count) selected")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MacBroomTheme.textSecondary)
                        Text("·")
                            .foregroundStyle(MacBroomTheme.textMuted)
                        Text(viewModel.totalSelectedSizeString)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(MacBroomTheme.textPrimary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                
                // Delete button — always visible, semi-transparent until selection
                Button(action: {
                    if appState.licenseManager.requiresActivation() {
                        appState.licenseManager.requestActivation()
                        return
                    }
                    showDeleteConfirm = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Delete")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(hasSelection ? .white : .white.opacity(0.3))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(hasSelection ?
                                  LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing) :
                                  LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: hasSelection ? .orange.opacity(0.3) : .clear, radius: 8, y: 4)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasSelection)
                .animation(MacBroomTheme.animationFast, value: hasSelection)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(MacBroomTheme.bgSecondary)
        }
    }
    
    private func performDelete() {
        viewModel.deleteSelected()
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: FileCategory
    let count: Int
    let totalSize: Int64
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var catColor: Color {
        switch category {
        case .all: return MacBroomTheme.accent
        case .videos: return .purple
        case .audios: return .pink
        case .images: return MacBroomTheme.success
        case .documents: return MacBroomTheme.warning
        case .archives: return .yellow
        case .other: return MacBroomTheme.textMuted
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(catColor.opacity(isSelected ? 0.25 : 0.1))
                        .frame(width: 28, height: 28)
                    Image(systemName: category.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(catColor)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? MacBroomTheme.textPrimary : MacBroomTheme.textSecondary)
                    HStack(spacing: 3) {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        Text("·")
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(MacBroomTheme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? catColor.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.02)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? catColor.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - File Row (full width, icon by type)
struct LargeFileRow: View {
    let file: FoundFile
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    private var catColor: Color {
        switch file.category {
        case .videos: return .purple
        case .audios: return .pink
        case .images: return MacBroomTheme.success
        case .documents: return MacBroomTheme.warning
        case .archives: return .yellow
        default: return MacBroomTheme.accent
        }
    }
    
    private var typeIcon: String {
        let ext = file.ext
        switch ext {
        // Videos
        case "mp4", "m4v": return "film.fill"
        case "mov": return "film.fill"
        case "avi", "mkv", "wmv", "flv": return "film.fill"
        // Audio
        case "mp3": return "music.note"
        case "wav", "aiff": return "waveform"
        case "m4a", "aac", "flac": return "music.note"
        // Images
        case "jpg", "jpeg": return "photo.fill"
        case "png": return "photo.fill"
        case "gif": return "photo.fill"
        case "heic": return "photo.fill"
        case "svg": return "photo.fill"
        // Documents
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.fill"
        case "xls", "xlsx", "csv": return "chart.bar.doc.fill"
        case "ppt", "pptx", "key": return "doc.richtext.fill"
        case "txt", "md", "rtf": return "doc.plaintext.fill"
        case "pages": return "doc.fill"
        case "numbers": return "chart.bar.doc.fill"
        // Archives
        case "zip": return "doc.zipper"
        case "dmg": return "internaldrive"
        case "rar", "7z", "tar", "gz": return "doc.zipper"
        // Dev
        case "xcodeproj", "xcworkspace": return "hammer.fill"
        case "swift": return "swift"
        case "js", "ts": return "curlybraces"
        case "py": return "terminal.fill"
        // Other
        default: return "doc.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            
            // Type icon with colored background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(catColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: typeIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(catColor)
            }
            
            // Name + path + extension badge
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if !file.ext.isEmpty {
                        Text(file.ext.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(catColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(catColor.opacity(0.12))
                            )
                    }
                    
                    Text(file.url.deletingLastPathComponent().path)
                        .font(.system(size: 10))
                        .foregroundStyle(MacBroomTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Modified date
            Text(file.modifiedDate, style: .date)
                .font(.system(size: 11))
                .foregroundStyle(MacBroomTheme.textSecondary)
                .frame(width: 80, alignment: .trailing)
            
            // Size — prominent
            VStack(alignment: .trailing, spacing: 2) {
                Text(file.sizeString)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                // Mini bar showing relative size
                if let maxSize = maxFileSize {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(catColor.opacity(0.4))
                            .frame(width: geo.size.width * CGFloat(Double(file.size) / Double(maxSize)))
                    }
                    .frame(width: 60, height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(width: 90, alignment: .trailing)
            
            // Reveal in Finder button
            Button(action: {
                NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? MacBroomTheme.accent.opacity(0.8) : MacBroomTheme.textMuted.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.04) : (isSelected ? MacBroomTheme.accent.opacity(0.04) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .onHover { isHovered = $0 }
    }
    
    private var maxFileSize: Int64? {
        // This would be better as a passed prop, but for now we estimate
        file.size > 1_000_000_000 ? file.size : nil
    }
}
