import SwiftUI

struct ActivationWindow: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var activationInput: String = ""
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
            
            Text("Activate MacBroom Pro")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 16)
            
            Text("Unlock all premium features")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
            
            // Price badge
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 11))
                Text("$9.99 — One-time purchase")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.40, green: 0.55, blue: 1.0))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(red: 0.40, green: 0.55, blue: 1.0).opacity(0.15))
            )
            .padding(.top, 12)
            
            // Purchase button (primary)
            VStack(spacing: 10) {
                // Buy via Paddle
                Button(action: {
                    licenseManager.openPurchase()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Purchase License — $9.99")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
                
                // Divider
                HStack {
                    VStack { Divider().background(Color.white.opacity(0.15)) }
                    Text("or activate with order ID")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                    VStack { Divider().background(Color.white.opacity(0.15)) }
                }
                .padding(.vertical, 4)
                
                // Transaction ID input
                VStack(alignment: .leading, spacing: 6) {
                    PasteableTextField(placeholder: "Enter your Paddle Order ID", text: $activationInput)
                        .frame(height: 24)
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
                    
                    // Activate button
                    Button(action: {
                        Task {
                            await licenseManager.activateWithPaddle(transactionId: activationInput)
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
                            Text(licenseManager.isActivating ? "Verifying..." : "Activate with Order ID")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.40, green: 0.55, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.40, green: 0.55, blue: 1.0).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(activationInput.count < 5 || licenseManager.isActivating)
                    .opacity(activationInput.count < 5 ? 0.5 : 1.0)
                    
                    // Lookup order
                    Button(action: {
                        licenseManager.openOrderLookup()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                            Text("Find my Order ID")
                                .font(.system(size: 11))
                                .underline()
                        }
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                
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
            .padding(.top, 16)
            .padding(.bottom, 28)
            
            Spacer()
        }
        .frame(width: 400, height: 540)
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.28), Color(red: 0.07, green: 0.09, blue: 0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Pasteable NSTextField wrapper
struct PasteableTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textField.delegate = context.coordinator
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        return textField
    }
    
    func updateNSView(_ nsTextField: NSTextField, context: Context) {
        nsTextField.stringValue = text
        nsTextField.placeholderString = placeholder
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PasteableTextField
        
        init(_ parent: PasteableTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func textFieldPressReturn(_ textField: NSTextField) -> Bool {
            parent.onSubmit?()
            return true
        }
    }
}
