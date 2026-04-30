import SwiftUI

// MARK: - Loading Dot Animation
struct LoadingDot: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -6 : 0)
            .opacity(isAnimating ? 1 : 0.4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Expandable Clean Tile
struct ExpandableCleanTile: View {
    let result: CleanableItem
    @ObservedObject var viewModel: SmartCleanViewModel
    var isReadOnly: Bool = false
    @State private var isExpanded = false
    @State private var isHovered = false
    
    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file)
    }
    
    private var selectedCount: Int {
        result.files.filter { viewModel.selectedFileIDs.contains($0.id) }.count
    }
    
    private var isAllSelected: Bool {
        !result.files.isEmpty && result.files.filter { $0.safetyLevel != .unsafe }.allSatisfy { viewModel.selectedFileIDs.contains($0.id) }
    }
    
    private var categorySafetyColor: Color {
        switch result.dominantSafety {
        case .safe: return .green
        case .caution: return .orange
        case .unsafe: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(categorySafetyColor)
                    .frame(width: 8, height: 8)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(result.category.color.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: result.category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(result.category.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MacBroomTheme.textPrimary)
                    HStack(spacing: 4) {
                        Text("\(result.files.count) items")
                        Text("•")
                        Text(sizeString)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                }
                
                Spacer()
                
                if !isReadOnly && selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(MacBroomTheme.accent))
                        .transition(.scale.combined(with: .opacity))
                }
                
                if !isReadOnly && !result.files.isEmpty {
                    Button(action: {
                        withAnimation(MacBroomTheme.animationFast) {
                            if isAllSelected { viewModel.deselectCategory(result.id) }
                            else { viewModel.selectCategory(result.id) }
                        }
                    }) {
                        Text(isAllSelected ? "Deselect" : "Select All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(MacBroomTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                Divider().opacity(0.2).padding(.horizontal, 14)
                
                if result.files.isEmpty {
                    Text("No files found")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 12)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(result.files) { file in
                            FileRow(
                                file: file,
                                isSelected: viewModel.selectedFileIDs.contains(file.id),
                                isReadOnly: isReadOnly || file.safetyLevel == .unsafe,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.toggleFile(file.id, inCategory: result.id)
                                    }
                                }
                            )
                            if file.id != result.files.last?.id {
                                Divider().opacity(0.15).padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                .fill(Color.white.opacity(isHovered ? 0.05 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(isHovered ? 0.10 : 0.04), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1), radius: isHovered ? 8 : 3, y: isHovered ? 3 : 1)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - File Row
struct FileRow: View {
    let file: CleanableFile
    let isSelected: Bool
    let isReadOnly: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
    }
    
    private var safetyColor: Color {
        switch file.safetyLevel {
        case .safe: return .green
        case .caution: return .orange
        case .unsafe: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(safetyColor).frame(width: 5, height: 5)
            
            if isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red.opacity(0.4))
            } else {
                Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                Text(file.path)
                    .font(.system(size: 9))
                    .foregroundStyle(MacBroomTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(sizeString)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(MacBroomTheme.textSecondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered && !isReadOnly ? Color.white.opacity(0.03) : Color.clear)
        )
        .opacity(isReadOnly ? 0.4 : 1.0)
        .onHover { isHovered = $0 }
    }
}
