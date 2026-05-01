import Foundation
import AppKit

// MARK: - Paddle Configuration
struct PaddleConfig {
    // Sandbox
    static let sandboxClientToken = "test_2c8cba0f566485fd10488cd7730"
    static let sandboxApiBase = "https://sandbox-api.paddle.com"
    
    // Production (set when going live)
    static let productionClientToken = ""
    static let productionApiBase = "https://api.paddle.com"
    
    // Current environment
    static var isSandbox: Bool = true
    
    static var clientToken: String {
        isSandbox ? sandboxClientToken : productionClientToken
    }
    
    static var apiBase: String {
        isSandbox ? sandboxApiBase : productionApiBase
    }
    
    // Product & Price IDs
    static let productId = "pro_01kqgr0jg7e8xc0nd25tgt7kg8"
    static let priceId = "pri_01kqgre9rdvsf6x659qqfegh2p"
    static let sellerId = "63262"
    
    // Checkout URL
    static var checkoutURL: String {
        if isSandbox {
            return "https://sandbox-buy.paddle.com/checkout/inline/\(priceId)"
        }
        return "https://buy.paddle.com/checkout/inline/\(priceId)"
    }
}

// MARK: - Paddle Transaction Response
struct PaddleTransactionResponse: Codable {
    let data: PaddleTransactionData?
    let meta: PaddleMeta?
    let error: PaddleError?
}

struct PaddleTransactionData: Codable {
    let id: String
    let status: String
    let customData: PaddleCustomData?
    let customerId: String?
    let billingPeriod: PaddleBillingPeriod?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case customData = "custom_data"
        case customerId = "customer_id"
        case billingPeriod = "billing_period"
    }
}

struct PaddleBillingPeriod: Codable {
    let frequency: Int?
    let interval: String?
}

struct PaddleCustomData: Codable {
    let licenseKey: String?
    
    enum CodingKeys: String, CodingKey {
        case licenseKey = "license_key"
    }
}

struct PaddleMeta: Codable {
    let requestID: String?
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
    }
}

struct PaddleError: Codable {
    let code: Int?
    let detail: String?
    let message: String?
}

// MARK: - Paddle Price Response
struct PaddlePriceResponse: Codable {
    let data: PaddlePriceData?
    let error: PaddleError?
}

struct PaddlePriceData: Codable {
    let id: String
    let unitPrice: PaddleUnitPrice?
    let billingCycle: PaddleBillingCycle?
    
    enum CodingKeys: String, CodingKey {
        case id
        case unitPrice = "unit_price"
        case billingCycle = "billing_cycle"
    }
}

struct PaddleUnitPrice: Codable {
    let amount: String
    let currencyCode: String
    
    enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
    }
}

struct PaddleBillingCycle: Codable {
    let interval: String?
    let frequency: Int?
}

// MARK: - Paddle Service
class PaddleService {
    static let shared = PaddleService()
    
    private let session = URLSession.shared
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
    
    private init() {}
    
    // MARK: - Open Checkout in Browser
    func openCheckout() {
        // Build checkout URL with price_id
        var components = URLComponents(string: PaddleConfig.isSandbox 
            ? "https://sandbox-buy.paddle.com/checkout" 
            : "https://buy.paddle.com/checkout")!
        
        components.queryItems = [
            URLQueryItem(name: "price_id", value: PaddleConfig.priceId),
            URLQueryItem(name: "custom_data", value: "{\"device_id\":\"\(SupabaseService.shared.deviceId)\"}")
        ]
        
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Verify Transaction
    /// Verify a completed Paddle transaction by transaction ID
    func verifyTransaction(transactionId: String) async throws -> LicenseInfo {
        let url = URL(string: "\(PaddleConfig.apiBase)/transactions/\(transactionId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(PaddleConfig.clientToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaddleError.internalError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = try? JSONDecoder().decode(PaddleTransactionResponse.self, from: data)
            throw PaddleError.internalError(errorBody?.error?.detail ?? "HTTP \(httpResponse.statusCode)")
        }
        
        let result = try jsonDecoder.decode(PaddleTransactionResponse.self, from: data)
        
        guard let transactionData = result.data else {
            throw PaddleError.internalError("No transaction data")
        }
        
        // Check if transaction is completed
        guard transactionData.status == "completed" || transactionData.status == "paid" || transactionData.status == "ready" else {
            throw PaddleError.internalError("Transaction not completed: \(transactionData.status)")
        }
        
        // Create license info from transaction
        let info = LicenseInfo(
            isValid: true,
            plan: "pro",
            billingCycle: "lifetime",
            deviceLimit: 1,
            email: "", // Will be filled from customer data
            expiresAt: nil, // One-time = lifetime
            message: nil
        )
        
        return info
    }
    
    // MARK: - Activate with Transaction ID
    /// User enters their Paddle transaction ID or order ID to activate
    func activateWithTransactionId(_ transactionId: String) async throws -> LicenseInfo {
        let trimmedId = transactionId.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await verifyTransaction(transactionId: trimmedId)
    }
    
    // MARK: - Get Price Info
    func getPriceInfo() async throws -> (amount: String, currency: String) {
        let url = URL(string: "\(PaddleConfig.apiBase)/prices/\(PaddleConfig.priceId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(PaddleConfig.clientToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        let result = try jsonDecoder.decode(PaddlePriceResponse.self, from: data)
        
        guard let priceData = result.data, let unitPrice = priceData.unitPrice else {
            throw PaddleError.internalError("Could not fetch price")
        }
        
        return (amount: unitPrice.amount, currency: unitPrice.currencyCode)
    }
    
    // MARK: - Generate Order Lookup URL
    /// Opens Paddle order lookup page so user can find their transaction ID
    func openOrderLookup() {
        let urlString = PaddleConfig.isSandbox 
            ? "https://sandbox-buy.paddle.com/order" 
            : "https://buy.paddle.com/order"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Paddle Errors
extension PaddleError: LocalizedError {
    static func internalError(_ message: String) -> PaddleError {
        return PaddleError(code: 0, detail: message, message: message)
    }
    
    var errorDescription: String? {
        detail ?? message ?? "Unknown Paddle error"
    }
}
