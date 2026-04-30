import SwiftUI

// MARK: - Animated Transition Modifier
struct FadeSlideTransition: ViewModifier {
    let isActive: Bool
    let direction: TransitionDirection
    
    enum TransitionDirection {
        case left, right, up, down
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(
                x: isActive ? 0 : (direction == .left ? -20 : direction == .right ? 20 : 0),
                y: isActive ? 0 : (direction == .up ? 20 : direction == .down ? -20 : 0)
            )
            .animation(MacBroomTheme.animationSpring, value: isActive)
    }
}

// MARK: - Staggered Animation
struct StaggeredAnimation: ViewModifier {
    let index: Int
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.7)
                .delay(Double(index) * 0.06),
                value: isVisible
            )
    }
}

// MARK: - Pulse Animation
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.15),
                            .clear
                        ],
                        startPoint: .init(x: phase, y: 0),
                        endPoint: .init(x: phase + 0.3, y: 0)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius))
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Glow Effect
struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isActive = false
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isActive ? 0.6 : 0), radius: radius)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isActive = true
                }
            }
    }
}

// MARK: - Progress Ring Animation
struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let size: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: lineWidth)
            
            // Progress
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Card Style
struct CardStyle: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: MacBroomTheme.cornerRadius)
                            .stroke(Color.white.opacity(isHovered ? 0.15 : 0.05), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 12 : 6, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(MacBroomTheme.animationFast, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
    
    func glow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
    
    func staggered(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredAnimation(index: index, isVisible: isVisible))
    }
}
