import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = AppDelegate.isLoginItemEnabled()
    @AppStorage("autoCleanEnabled") private var autoCleanEnabled = false
    @AppStorage("cleanFrequency") private var cleanFrequency = "Weekly"
    @State private var isVisible = false
    
    private var lang: AppLanguage { appState.currentLanguage }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L.settings(lang))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MacBroomTheme.textPrimary)
                
                // General
                SettingsSection(
                    title: L.settingsGeneral(lang),
                    icon: "gearshape.2.fill",
                    color: MacBroomTheme.accent,
                    index: 0,
                    isVisible: isVisible
                ) {
                    SettingsRow(icon: "power", title: L.launchAtLogin(lang)) {
                        Toggle("", isOn: $launchAtLogin).toggleStyle(.switch)
                    }
                    SettingsRow(icon: "menubar.rectangle", title: L.showMenuBar(lang)) {
                        Toggle("", isOn: .constant(true)).toggleStyle(.switch)
                    }
                    SettingsRow(icon: "globe", title: L.language(lang)) {
                        Picker("", selection: Binding(
                            get: { appState.currentLanguage },
                            set: { appState.currentLanguage = $0 }
                        )) {
                            Text("English").tag(AppLanguage.english)
                            Text("العربية").tag(AppLanguage.arabic)
                        }
                        .frame(width: 140)
                    }
                }
                
                // Cleaning
                SettingsSection(
                    title: L.cleaningSection(lang),
                    icon: "sparkles",
                    color: .orange,
                    index: 1,
                    isVisible: isVisible
                ) {
                    SettingsRow(icon: "clock.arrow.circlepath", title: "Enable Auto Clean") {
                        Toggle("", isOn: $autoCleanEnabled).toggleStyle(.switch)
                    }
                    
                    if autoCleanEnabled {
                        SettingsRow(icon: "calendar", title: "Frequency") {
                            Picker("", selection: $cleanFrequency) {
                                Text("Daily").tag("Daily")
                                Text("Weekly").tag("Weekly")
                                Text("Monthly").tag("Monthly")
                            }
                            .frame(width: 120)
                        }
                    }
                }
                
                // Safety
                SettingsSection(
                    title: L.safety(lang),
                    icon: "shield.checkered",
                    color: .green,
                    index: 2,
                    isVisible: isVisible
                ) {
                    SettingsRow(icon: "checkmark.circle", title: L.confirmBeforeDelete(lang)) {
                        Toggle("", isOn: .constant(true)).toggleStyle(.switch)
                    }
                    SettingsRow(icon: "externaldrive.badge.timemachine", title: L.keepBackup(lang)) {
                        Toggle("", isOn: .constant(true)).toggleStyle(.switch)
                    }
                }
                
                // License
                SettingsSection(
                    title: "License",
                    icon: "key.fill",
                    color: .purple,
                    index: 3,
                    isVisible: isVisible
                ) {
                    if appState.licenseManager.isActivated {
                        // Active license info
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.licenseManager.subscriptionDisplayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(MacBroomTheme.textPrimary)
                                    
                                    Text(appState.licenseManager.email)
                                        .font(.system(size: 12))
                                        .foregroundStyle(MacBroomTheme.textSecondary)
                                }
                                
                                Spacer()
                            }
                            
                            // Billing info
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "desktopcomputer")
                                        .font(.system(size: 11))
                                        .foregroundStyle(MacBroomTheme.textSecondary)
                                    Text("\(appState.licenseManager.deviceLimit) Mac\(appState.licenseManager.deviceLimit > 1 ? "s" : "")")
                                        .font(.system(size: 12))
                                        .foregroundStyle(MacBroomTheme.textSecondary)
                                }
                                
                                if appState.licenseManager.isLifetime {
                                    HStack(spacing: 4) {
                                        Image(systemName: "infinity")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.green)
                                        Text("Lifetime")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green)
                                    }
                                } else if let days = appState.licenseManager.daysRemaining {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(days < 30 ? .orange : MacBroomTheme.textSecondary)
                                        Text("\(days) days remaining")
                                            .font(.system(size: 12))
                                            .foregroundStyle(days < 30 ? .orange : MacBroomTheme.textSecondary)
                                    }
                                }
                            }
                            
                            // Deactivate button
                            Button(action: {
                                appState.licenseManager.deactivate()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 11))
                                    Text("Deactivate License")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.red.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // No license
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Free Version")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(MacBroomTheme.textPrimary)
                                Text("Activate to unlock all features")
                                    .font(.system(size: 12))
                                    .foregroundStyle(MacBroomTheme.textSecondary)
                            }
                            Spacer()
                            Button(action: {
                                appState.licenseManager.requestActivation()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 11))
                                    Text("Activate")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(MacBroomTheme.accentGradient)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // About
                SettingsSection(
                    title: L.about(lang),
                    icon: "info.circle.fill",
                    color: .blue,
                    index: 4,
                    isVisible: isVisible
                ) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(MacBroomTheme.accentGradient)
                                .frame(width: 40, height: 40)
                            Image(systemName: "sparkle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MacBroom")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("Version \(AppVersion.fullVersion)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Built with \u{2764}\u{FE0F} by Al-Heekmah Library")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Check for Updates button
                        Button(action: {
                            UpdateManager.shared.checkForUpdates()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Check for Updates")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(MacBroomTheme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(MacBroomTheme.accent.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(MacBroomTheme.accent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { isVisible = true }
        .onChange(of: launchAtLogin) { newValue in
            AppDelegate.setLoginItemEnabled(newValue)
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let index: Int
    let isVisible: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MacBroomTheme.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .staggered(index: index, isVisible: isVisible)
    }
}

// MARK: - Settings Row
struct SettingsRow<Control: View>: View {
    let icon: String
    let title: String
    let control: () -> Control
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(MacBroomTheme.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MacBroomTheme.textPrimary)
            
            Spacer()
            
            control()
        }
        .padding(.vertical, 6)
    }
}
