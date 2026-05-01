import Foundation
import SwiftUI

// MARK: - License Manager
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var isActivated: Bool = false
    @Published var plan: String = "free"
    @Published var billingCycle: String = "lifetime"
    @Published var deviceLimit: Int = 1
    @Published var email: String = ""
    @Published var expiresAt: Date?
    @Published var showActivationDialog: Bool = false
    @Published var isActivating: Bool = false
    @Published var activationError: String?
    @Published var activationSuccess: Bool = false
    
    // Activation mode
    @Published var activationMode: ActivationMode = .licenseKey
    
    enum ActivationMode {
        case licenseKey    // Supabase license key (MACBROOM-XXXX...)
        case paddleOrder   // Paddle transaction/order ID
    }
    
    private let supabase = SupabaseService.shared
    private let paddle = PaddleService.shared
    
    private init() {
        checkLocalLicense()
    }
    
    // MARK: - Check local license on startup
    private func checkLocalLicense() {
        // Check if activated via Paddle
        if let paddleTx = UserDefaults.standard.string(forKey: "macbroom_paddle_transaction"), !paddleTx.isEmpty {
            isActivated = true
            plan = UserDefaults.standard.string(forKey: "macbroom_plan") ?? "pro"
            billingCycle = UserDefaults.standard.string(forKey: "macbroom_billing_cycle") ?? "lifetime"
            deviceLimit = UserDefaults.standard.integer(forKey: "macbroom_device_limit")
            if deviceLimit == 0 { deviceLimit = 1 }
            email = UserDefaults.standard.string(forKey: "macbroom_email") ?? ""
            let expiryInterval = UserDefaults.standard.double(forKey: "macbroom_expires")
            if expiryInterval > 0 {
                expiresAt = Date(timeIntervalSince1970: expiryInterval)
            }
            
            Task { await validatePaddleTransaction() }
            return
        }
        
        // Check Supabase license
        if let local = supabase.getLocalLicense() {
            isActivated = true
            plan = local.plan
            billingCycle = UserDefaults.standard.string(forKey: "macbroom_billing_cycle") ?? "lifetime"
            deviceLimit = UserDefaults.standard.integer(forKey: "macbroom_device_limit")
            if deviceLimit == 0 { deviceLimit = 1 }
            email = UserDefaults.standard.string(forKey: "macbroom_email") ?? ""
            let expiryInterval = UserDefaults.standard.double(forKey: "macbroom_expires")
            if expiryInterval > 0 {
                expiresAt = Date(timeIntervalSince1970: expiryInterval)
            }
            
            Task { await validateWithServer() }
        }
    }
    
    // MARK: - Validate with Supabase server
    func validateWithServer() async {
        do {
            let info = try await supabase.validateLicense()
            await MainActor.run {
                if info.isValid {
                    isActivated = true
                    plan = info.plan
                    billingCycle = info.billingCycle
                    deviceLimit = info.deviceLimit
                    email = info.email
                    expiresAt = info.expiresAt
                    supabase.saveLicenseLocally(key: supabase.getLocalLicense()?.key ?? "", info: info)
                } else {
                    isActivated = false
                    plan = "free"
                    billingCycle = "lifetime"
                    deviceLimit = 1
                    supabase.clearLocalLicense()
                }
            }
        } catch {
            print("License validation failed (offline?): \(error)")
        }
    }
    
    // MARK: - Validate Paddle transaction
    private func validatePaddleTransaction() async {
        guard let txId = UserDefaults.standard.string(forKey: "macbroom_paddle_transaction") else { return }
        
        do {
            let info = try await paddle.verifyTransaction(transactionId: txId)
            await MainActor.run {
                if info.isValid {
                    isActivated = true
                    plan = info.plan
                    billingCycle = info.billingCycle
                    deviceLimit = info.deviceLimit
                    email = info.email
                    expiresAt = info.expiresAt
                } else {
                    // Transaction no longer valid
                    isActivated = false
                    plan = "free"
                    clearPaddleLicense()
                }
            }
        } catch {
            // Offline — keep local activation
            print("Paddle validation failed (offline?): \(error)")
        }
    }
    
    // MARK: - Activate with Supabase license key
    func activate(key: String) async {
        await MainActor.run {
            isActivating = true
            activationError = nil
            activationSuccess = false
        }
        
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        do {
            let info = try await supabase.activateLicense(key: trimmedKey)
            
            await MainActor.run {
                isActivating = false
                
                if info.isValid {
                    isActivated = true
                    plan = info.plan
                    billingCycle = info.billingCycle
                    deviceLimit = info.deviceLimit
                    email = info.email
                    expiresAt = info.expiresAt
                    activationSuccess = true
                    showActivationDialog = false
                } else {
                    activationError = info.message ?? "Invalid license key"
                }
            }
        } catch {
            await MainActor.run {
                isActivating = false
                activationError = "Connection error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Activate with Paddle Transaction ID
    func activateWithPaddle(transactionId: String) async {
        await MainActor.run {
            isActivating = true
            activationError = nil
            activationSuccess = false
        }
        
        do {
            let info = try await paddle.activateWithTransactionId(transactionId)
            
            await MainActor.run {
                isActivating = false
                
                if info.isValid {
                    isActivated = true
                    plan = info.plan
                    billingCycle = info.billingCycle
                    deviceLimit = info.deviceLimit
                    email = info.email
                    expiresAt = info.expiresAt
                    
                    // Save Paddle transaction locally
                    UserDefaults.standard.set(transactionId, forKey: "macbroom_paddle_transaction")
                    supabase.saveLicenseLocally(key: "paddle_\(transactionId)", info: info)
                    
                    activationSuccess = true
                    showActivationDialog = false
                } else {
                    activationError = "Transaction not valid or not completed"
                }
            }
        } catch {
            await MainActor.run {
                isActivating = false
                activationError = "Paddle error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Open Paddle Checkout
    func openPurchase() {
        paddle.openCheckout()
    }
    
    // MARK: - Open Order Lookup
    func openOrderLookup() {
        paddle.openOrderLookup()
    }
    
    // MARK: - Deactivate
    func deactivate() {
        isActivated = false
        plan = "free"
        billingCycle = "lifetime"
        deviceLimit = 1
        email = ""
        expiresAt = nil
        
        // Clear both
        supabase.clearLocalLicense()
        clearPaddleLicense()
    }
    
    private func clearPaddleLicense() {
        UserDefaults.standard.removeObject(forKey: "macbroom_paddle_transaction")
    }
    
    // MARK: - Request activation dialog
    func requestActivation() {
        activationError = nil
        activationSuccess = false
        activationMode = .paddleOrder
        showActivationDialog = true
    }
    
    // MARK: - Check if feature requires license
    func requiresActivation() -> Bool {
        return !isActivated
    }
    
    var planDisplayName: String {
        switch plan {
        case "pro": return "Pro"
        default: return "Free"
        }
    }
    
    var billingCycleDisplayName: String {
        switch billingCycle {
        case "monthly": return "Monthly"
        case "yearly": return "Yearly"
        case "lifetime": return "Lifetime"
        default: return "Lifetime"
        }
    }
    
    var subscriptionDisplayName: String {
        if plan == "free" { return "Free" }
        return "Pro \(billingCycleDisplayName) (\(deviceLimit) Mac)"
    }
    
    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return expiry < Date()
    }
    
    var isLifetime: Bool {
        return billingCycle == "lifetime"
    }
    
    var daysRemaining: Int? {
        guard let expiry = expiresAt, billingCycle != "lifetime" else { return nil }
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
        return remaining
    }
    
    var isPaddleActivated: Bool {
        return UserDefaults.standard.string(forKey: "macbroom_paddle_transaction") != nil
    }
}
