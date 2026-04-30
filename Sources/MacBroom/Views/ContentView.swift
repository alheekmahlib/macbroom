import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isWindowFocused = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom title bar
            customTitleBar
            
            // Main content
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: MacBroomTheme.sidebarWidth)
                
                // Page content
                ZStack {
                    switch appState.selectedPage {
                    case .home:
                        HomeView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity
                            ))
                    case .smartClean:
                        SmartCleanView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .largeFiles:
                        LargeFilesView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .diskAnalyzer:
                        DiskAnalyzerView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .ramBooster:
                        RamBoosterView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .appUninstaller:
                        AppUninstallerView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .systemMonitor:
                        SystemMonitorView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .settings:
                        SettingsView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(MacBroomTheme.animationNormal, value: appState.selectedPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MacBroomTheme.bgPrimary)
        .environment(\.layoutDirection, appState.currentLanguage.layoutDirection)
        .sheet(isPresented: Binding(
            get: { appState.licenseManager.showActivationDialog },
            set: { appState.licenseManager.showActivationDialog = $0 }
        )) {
            ActivationWindow(licenseManager: appState.licenseManager)
                .frame(width: 400, height: 460)
        }
    }
    
    // MARK: - Custom Title Bar
    private var customTitleBar: some View {
        HStack(spacing: 0) {
            
            // App title
            HStack(spacing: 8) {
                AppIconView(size: 16)
                
                Text("MacBroom")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            
            Spacer()
            // Settings gear
            Button(action: {
                withAnimation(MacBroomTheme.animationSpring) {
                    appState.selectedPage = .settings
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(MacBroomTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .frame(height: 38)
        .background(
            MacBroomTheme.bgSecondary
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                    }
                )
        )
    }
}
