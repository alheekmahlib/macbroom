import SwiftUI

// MARK: - Modern Progress Bar
struct MacBroomProgressBar: View {
    let progress: CGFloat  // 0.0 - 1.0
    let color: Color
    var height: CGFloat = 8
    var showLabel: Bool = true
    var cornerRadius: CGFloat = 4
    
    @State private var animatedProgress: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: height)
                    
                    // Fill with shimmer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * animatedProgress, height: height)
                        .overlay(
                            // Shimmer sweep
                            Group {
                                if animatedProgress > 0 && animatedProgress < 1 {
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .fill(
                                            LinearGradient(
                                                colors: [.clear, .white.opacity(0.3), .clear],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 40, height: height)
                                        .offset(x: geo.size.width * animatedProgress - 40)
                                        .transition(.opacity)
                                }
                            }
                        )
                }
            }
            .frame(height: height)
            
            if showLabel {
                HStack {
                    Spacer()
                    Text(String(format: "%.0f%%", animatedProgress * 100))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Circular Progress
struct MacBroomCircularProgress: View {
    let progress: CGFloat
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    
    @State private var animatedProgress: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.12), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Glow at tip
            Circle()
                .fill(color)
                .frame(width: lineWidth + 2, height: lineWidth + 2)
                .blur(radius: 4)
                .opacity(0.6)
                .offset(
                    x: (size / 2 - lineWidth / 2) * CGFloat(cos(2 * .pi * Double(animatedProgress) - .pi / 2)),
                    y: (size / 2 - lineWidth / 2) * CGFloat(sin(2 * .pi * Double(animatedProgress) - .pi / 2))
                )
                .opacity(animatedProgress > 0.01 ? 0.6 : 0)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}
