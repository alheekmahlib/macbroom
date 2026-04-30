import SwiftUI

struct ActivationWindow: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var licenseKey: String = ""
    @State private var isHoveringBuy: Bool = false
    
    private let websiteURL = "https://macbroom.com"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.40, green: 0.55, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.4), radius: 12, y: 4)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 32)
            
            Text("Activate MacBroom")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 16)
            
            Text("Enter your license key to unlock all features")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
            
            // Input
            VStack(alignment: .leading, spacing: 6) {
                TextField("MACBROOM-XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(4)
                
                if let error = licenseManager.activationError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text(error)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.red)
                }
                
                if licenseManager.activationSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Activated successfully!")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            
            // Buttons
            VStack(spacing: 10) {
                // Activate
                Button(action: {
                    Task {
                        await licenseManager.activate(key: licenseKey)
                    }
                }) {
                    HStack(spacing: 8) {
                        if licenseManager.isActivating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "key.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(licenseManager.isActivating ? "Activating..." : "I have a License Key")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.40, green: 0.55, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(licenseKey.count < 10 || licenseManager.isActivating)
                .opacity(licenseKey.count < 10 ? 0.5 : 1.0)
                
                // Buy
                Button(action: {
                    if let url = URL(string: websiteURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Purchase a License")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.40, green: 0.55, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.40, green: 0.55, blue: 1.0).opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Skip
                Button(action: {
                    licenseManager.showActivationDialog = false
                }) {
                    Text("Continue with Free Version")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 28)
            
            Spacer()
        }
        .frame(width: 400, height: 460)
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.28), Color(red: 0.07, green: 0.09, blue: 0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
