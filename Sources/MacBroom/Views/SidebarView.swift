import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredPage: AppState.Page?
    
    private var lang: AppLanguage { appState.currentLanguage }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo area
            sidebarHeader
                .padding(.top, 24)
                .padding(.bottom, 20)
            
            // Navigation items
            VStack(spacing: 2) {
                ForEach(Array(AppState.Page.allCases.enumerated()), id: \.element) { index, page in
                    SidebarButton(
                        page: page,
                        isSelected: appState.selectedPage == page,
                        isHovered: hoveredPage == page,
                        language: lang,
                        action: {
                            withAnimation(MacBroomTheme.animationSpring) {
                                appState.selectedPage = page
                            }
                        }
                    )
                    .staggered(index: index, isVisible: true)
                    .onHover { hover in
                        hoveredPage = hover ? page : nil
                    }
                }
            }
            .padding(.horizontal, 14)
            
            Spacer()
            
            // Storage bar at bottom
            StorageBarView()
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        .background(
            ZStack {
                MacBroomTheme.bgSecondary
                // Subtle top glow
                VStack {
                    RadialGradient(
                        colors: [MacBroomTheme.accent.opacity(0.06), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 250
                    )
                    .frame(height: 200)
                    Spacer()
                }
                // Right edge subtle separator
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.06), .white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1)
                }
            }
        )
    }
    
    // MARK: - Logo
    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(MacBroomTheme.accentGradient)
                    .frame(width: 38, height: 38)
                    .shadow(color: MacBroomTheme.accent.opacity(0.4), radius: 8, y: 2)
                
                    AppIconView(size: 26)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("MacBroom")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                Text("System Cleaner")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacBroomTheme.textMuted)
            }
            
            Spacer()
        }
        .padding(.horizontal, 18)
    }
}

// MARK: - Sidebar Button
struct SidebarButton: View {
    let page: AppState.Page
    let isSelected: Bool
    let isHovered: Bool
    let language: AppLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(MacBroomTheme.accent.opacity(0.2))
                            .frame(width: 34, height: 34)
                    }
                    
                    Image(systemName: page.icon)
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(
                            isSelected ? MacBroomTheme.accentLight :
                            (isHovered ? MacBroomTheme.textPrimary : MacBroomTheme.textSecondary)
                        )
                }
                .frame(width: 34, height: 34)
                
                // Label
                Text(page.localizedName(language))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected ? MacBroomTheme.textPrimary :
                        (isHovered ? MacBroomTheme.textPrimary : MacBroomTheme.textSecondary)
                    )
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected ? MacBroomTheme.accent.opacity(0.12) :
                        (isHovered ? Color.white.opacity(0.04) : Color.clear)
                    )
            )
            // Left accent bar for selected
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MacBroomTheme.accentGradient)
                            .frame(width: 3, height: 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Storage Bar
struct StorageBarView: View {
    @EnvironmentObject var appState: AppState
    
    private var usedGB: Double {
        Double(appState.totalStorageUsed) / 1_073_741_824
    }
    
    private var totalGB: Double {
        Double(appState.totalStorageCapacity) / 1_073_741_824
    }
    
    private var percent: Double {
        guard appState.totalStorageCapacity > 0 else { return 0 }
        return Double(appState.totalStorageUsed) / Double(appState.totalStorageCapacity)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11))
                    .foregroundStyle(MacBroomTheme.accent)
                
                Text(String(format: "%.0f GB / %.0f GB", usedGB, totalGB))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textSecondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", percent * 100))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(percent > 0.85 ? MacBroomTheme.danger : MacBroomTheme.textSecondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: percent > 0.85 ?
                                    [MacBroomTheme.warning, MacBroomTheme.danger] :
                                    [MacBroomTheme.accent, MacBroomTheme.accentLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(percent))
                        .animation(MacBroomTheme.animationNormal, value: percent)
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadiusSmall)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
