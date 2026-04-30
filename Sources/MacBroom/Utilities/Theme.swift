import SwiftUI

// MARK: - MacBroom Theme — Deep Ocean Design
struct MacBroomTheme {
    // MARK: Primary Colors — Deep blue-purple palette
    static let accent = Color(red: 0.25, green: 0.45, blue: 0.95)        // Bright blue #4073F2
    static let accentLight = Color(red: 0.35, green: 0.55, blue: 1.0)   // Lighter blue
    static let accentDark = Color(red: 0.15, green: 0.30, blue: 0.75)   // Dark blue
    
    // Semantic colors
    static let success = Color(red: 0.20, green: 0.80, blue: 0.55)      // Green
    static let warning = Color(red: 1.0, green: 0.65, blue: 0.15)       // Orange
    static let danger = Color(red: 0.95, green: 0.30, blue: 0.35)       // Red
    
    // MARK: Backgrounds — Deep dark navy
    static let bgPrimary = Color(red: 0.07, green: 0.09, blue: 0.18)    // #121D2E deep navy
    static let bgSecondary = Color(red: 0.06, green: 0.08, blue: 0.16)  // #0F1429 darker navy (sidebar)
    static let bgCard = Color(red: 0.10, green: 0.13, blue: 0.25)       // #1A2140 card bg
    static let bgCardHover = Color(red: 0.13, green: 0.16, blue: 0.30)  // #212A4D card hover
    static let bgElevated = Color(red: 0.14, green: 0.18, blue: 0.32)   // #242E52 elevated
    
    // Text
    static let textPrimary = Color(red: 0.92, green: 0.94, blue: 0.97)  // Near white
    static let textSecondary = Color(red: 0.55, green: 0.60, blue: 0.72) // Muted blue-gray
    static let textMuted = Color(red: 0.35, green: 0.40, blue: 0.52)    // Very muted
    
    // MARK: Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.40, green: 0.55, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let scanGradient = LinearGradient(
        colors: [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.50, blue: 1.0), Color(red: 0.20, green: 0.65, blue: 0.90)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let healthGoodGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.80, blue: 0.55), Color(red: 0.15, green: 0.65, blue: 0.90)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let healthBadGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.55, blue: 0.15), Color(red: 0.95, green: 0.30, blue: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let sidebarGlow = RadialGradient(
        colors: [Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.08), .clear],
        center: .top,
        startRadius: 20,
        endRadius: 300
    )
    
    // MARK: Sizes
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusSmall: CGFloat = 10
    static let sidebarWidth: CGFloat = 230
    
    // MARK: Animations
    static let animationFast: Animation = .easeInOut(duration: 0.2)
    static let animationNormal: Animation = .easeInOut(duration: 0.35)
    static let animationSpring: Animation = .spring(response: 0.4, dampingFraction: 0.75)
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    var isHovered: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(isHovered ? 0.15 : 0.06), .white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: isHovered ? 12 : 6, y: isHovered ? 4 : 2)
            )
    }
}

extension View {
    func glassCard(isHovered: Bool = false) -> some View {
        modifier(GlassCard(isHovered: isHovered))
    }
}
