import Foundation
import Supabase

// MARK: - Supabase Configuration
struct SupabaseConfig {
    static let url = URL(string: "https://yprhjinkisfgnaokzxwq.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlwcmhqaW5raXNmZ25hb2t6eHdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMzEyODAsImV4cCI6MjA5MjkwNzI4MH0.Ft6_nBmvsm0h1aJjS52rWLliqidDkle4Cxxx0j5JIsY"
}

// MARK: - License Models
struct LicenseValidationResult: Codable {
    let valid: Bool
    let plan: String
    let billingCycle: String?
    let deviceLimit: Int?
    let email: String
    let expiresAt: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case valid, plan, email, message
        case billingCycle = "billing_cycle"
        case deviceLimit = "device_limit"
        case expiresAt = "expires_at"
    }
}

struct LicenseInfo {
    let isValid: Bool
    let plan: String
    let billingCycle: String
    let deviceLimit: Int
    let email: String
    let expiresAt: Date?
    let message: String?
}

// MARK: - Supabase Service
class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }
    
    // MARK: - Device ID
    var deviceId: String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-rd1", "-c", "IOPlatformExpertDevice"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return UUID().uuidString }
            
            if let range = output.range(of: "\"IOPlatformUUID\" = \"") {
                let start = range.upperBound
                let end = output[start...].firstIndex(of: "\"") ?? output.endIndex
                return String(output[start..<end])
            }
        } catch {}
        
        return UUID().uuidString
    }
    
    var deviceName: String {
        Host.current().localizedName ?? "Unknown Mac"
    }
    
    // MARK: - Activate License
    func activateLicense(key: String) async throws -> LicenseInfo {
        let response: [LicenseValidationResult] = try await client
            .rpc("activate_license", params: [
                "p_key": key,
                "p_device_id": deviceId,
                "p_device_name": deviceName
            ])
            .execute()
            .value
        
        guard let result = response.first else {
            return LicenseInfo(isValid: false, plan: "free", billingCycle: "lifetime", deviceLimit: 1, email: "", expiresAt: nil, message: "No response from server")
        }
        
        let expiry = parseDate(result.expiresAt)
        let info = LicenseInfo(
            isValid: result.valid,
            plan: result.plan,
            billingCycle: result.billingCycle ?? "lifetime",
            deviceLimit: result.deviceLimit ?? 1,
            email: result.email,
            expiresAt: expiry,
            message: result.message
        )
        
        if result.valid {
            saveLicenseLocally(key: key, info: info)
        }
        
        return info
    }
    
    // MARK: - Validate License
    func validateLicense() async throws -> LicenseInfo {
        let response: [LicenseValidationResult] = try await client
            .rpc("validate_license", params: [
                "p_device_id": deviceId
            ])
            .execute()
            .value
        
        guard let result = response.first else {
            return LicenseInfo(isValid: false, plan: "free", billingCycle: "lifetime", deviceLimit: 1, email: "", expiresAt: nil, message: nil)
        }
        
        let expiry = parseDate(result.expiresAt)
        return LicenseInfo(
            isValid: result.valid,
            plan: result.plan,
            billingCycle: result.billingCycle ?? "lifetime",
            deviceLimit: result.deviceLimit ?? 1,
            email: result.email,
            expiresAt: expiry,
            message: result.message
        )
    }
    
    // MARK: - Local Storage
    func saveLicenseLocally(key: String, info: LicenseInfo) {
        UserDefaults.standard.set(key, forKey: "macbroom_license_key")
        UserDefaults.standard.set(info.plan, forKey: "macbroom_plan")
        UserDefaults.standard.set(info.billingCycle, forKey: "macbroom_billing_cycle")
        UserDefaults.standard.set(info.deviceLimit, forKey: "macbroom_device_limit")
        UserDefaults.standard.set(info.email, forKey: "macbroom_email")
        if let expiry = info.expiresAt {
            UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: "macbroom_expires")
        }
    }
    
    func getLocalLicense() -> (key: String, plan: String)? {
        guard let key = UserDefaults.standard.string(forKey: "macbroom_license_key"),
              let plan = UserDefaults.standard.string(forKey: "macbroom_plan") else {
            return nil
        }
        return (key, plan)
    }
    
    func isLocallyActivated() -> Bool {
        return getLocalLicense() != nil
    }
    
    func clearLocalLicense() {
        UserDefaults.standard.removeObject(forKey: "macbroom_license_key")
        UserDefaults.standard.removeObject(forKey: "macbroom_plan")
        UserDefaults.standard.removeObject(forKey: "macbroom_billing_cycle")
        UserDefaults.standard.removeObject(forKey: "macbroom_device_limit")
        UserDefaults.standard.removeObject(forKey: "macbroom_email")
        UserDefaults.standard.removeObject(forKey: "macbroom_expires")
    }
    
    // MARK: - Helpers
    private func parseDate(_ string: String?) -> Date? {
        guard let string = string, !string.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
