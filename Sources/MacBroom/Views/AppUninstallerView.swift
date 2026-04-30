import SwiftUI

struct AppUninstallerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AppUninstallerViewModel()
    @State private var searchText = ""
    
    private var filteredApps: [InstalledApp] {
        if searchText.isEmpty { return viewModel.apps }
        return viewModel.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Uninstaller")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(MacBroomTheme.textPrimary)
                    Text("Remove apps or clean their data safely")
                        .font(.subheadline)
                        .foregroundStyle(MacBroomTheme.textSecondary)
                }
                Spacer()
                
                Button(action: { viewModel.refreshApps() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 24)
            
            Divider().padding(.vertical, 12)
            
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading apps...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // App List with expandable tiles
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            ExpandableAppTile(app: app, viewModel: viewModel, licenseManager: appState.licenseManager)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .onAppear { viewModel.refreshApps() }
    }
}

// MARK: - Expandable App Tile
struct ExpandableAppTile: View {
    let app: InstalledApp
    @ObservedObject var viewModel: AppUninstallerViewModel
    @ObservedObject var licenseManager: LicenseManager
    @State private var isExpanded = false
    @State private var relatedFiles: [AppFileItem] = []
    @State private var isLoadingFiles = false
    @State private var selectedFileIDs: Set<UUID> = []
    
    private var appSize: String {
        ByteCountFormatter.string(fromByteCount: app.size, countStyle: .file)
    }
    
    private var totalSelectedSize: String {
        let total = relatedFiles
            .filter { selectedFileIDs.contains($0.id) }
            .reduce(Int64(0)) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // App header
            HStack(spacing: 12) {
                if let iconPath = app.iconPath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: iconPath))
                        .resizable()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "app.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(appSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
                if relatedFiles.isEmpty && !isLoadingFiles {
                    loadRelatedFiles()
                }
            }
            
            // Expanded content
            if isExpanded {
                Divider().padding(.horizontal, 12)
                
                if isLoadingFiles {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning files...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(relatedFiles) { file in
                            AppFileRow(
                                file: file,
                                isSelected: selectedFileIDs.contains(file.id),
                                onToggle: {
                                    if selectedFileIDs.contains(file.id) {
                                        selectedFileIDs.remove(file.id)
                                    } else {
                                        selectedFileIDs.insert(file.id)
                                    }
                                }
                            )
                            
                            if file.id != relatedFiles.last?.id {
                                Divider().padding(.leading, 44)
                            }
                        }
                        
                        // Action buttons
                        HStack {
                            Button("Select All") {
                                selectedFileIDs = Set(relatedFiles.map(\.id))
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.teal)
                            
                            Button("Deselect All") {
                                selectedFileIDs = []
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if !selectedFileIDs.isEmpty {
                                Text("\(totalSelectedSize) selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Delete selected files only
                            if !selectedFileIDs.isEmpty {
                                Button(role: .destructive, action: {
                                    if licenseManager.requiresActivation() {
                                        licenseManager.requestActivation()
                                        return
                                    }
                                    viewModel.deleteSelectedFiles(
                                        app: app,
                                        fileIDs: selectedFileIDs,
                                        files: relatedFiles
                                    )
                                    selectedFileIDs = []
                                    loadRelatedFiles()
                                }) {
                                    Label("Delete Selected", systemImage: "trash.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.small)
                            }
                            
                            // Uninstall whole app
                            Button(role: .destructive, action: {
                                if licenseManager.requiresActivation() {
                                    licenseManager.requestActivation()
                                    return
                                }
                                viewModel.uninstallApp(app)
                            }) {
                                Label("Uninstall App", systemImage: "xmark.bin.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func loadRelatedFiles() {
        isLoadingFiles = true
        DispatchQueue.global(qos: .userInitiated).async {
            let files = AppUninstallerService.shared.findRelatedFilesDetailed(for: app)
            DispatchQueue.main.async {
                relatedFiles = files
                // Auto-select safe files only
                selectedFileIDs = Set(files.filter { $0.safetyLevel == .safe }.map(\.id))
                isLoadingFiles = false
            }
        }
    }
}

// MARK: - App File Row
struct AppFileRow: View {
    let file: AppFileItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(safetyColor)
                .frame(width: 6, height: 6)
            
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(file.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Text(file.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .toggleStyle(.checkbox)
            
            Spacer()
            
            if file.safetyLevel == .caution {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text("Caution")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.orange)
            } else if file.safetyLevel == .unsafe {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 9))
                    Text("Keep")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.red)
            }
            
            Text(sizeString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .opacity(file.safetyLevel == .unsafe ? 0.5 : 1.0)
    }
    
    private var safetyColor: Color {
        switch file.safetyLevel {
        case .safe: return .green
        case .caution: return .orange
        case .unsafe: return .red
        }
    }
}
