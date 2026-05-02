import Foundation
import AppKit

// MARK: - Paddle Configuration
struct PaddleConfig {
    // Sandbox
    // Sandbox — loaded from Secrets.swift (excluded from git)
    static let sandboxApiKey = Secrets.paddleSandboxApiKey
    static let sandboxApiBase = "https://sandbox-api.paddle.com"
    
    // Production (set when going live)
    static let productionApiKey = ""
    static let productionApiBase = "https://api.paddle.com"
    
    // Current environment
    static var isSandbox: Bool = true
    
    static var apiKey: String {
        isSandbox ? sandboxApiKey : productionApiKey
    }
    
    static var apiBase: String {
        isSandbox ? sandboxApiBase : productionApiBase
    }
    
    // Product & Price IDs
    static let productId = "pro_01kqgr0jg7e8xc0nd25tgt7kg8"
    static let sellerId = "63262"
    
    // Price IDs by plan
    struct Prices {
        // Monthly
        static let monthly1Mac = "pri_01kqh0drf99e6b54px0bexn9ac"   // $4.99/mo
        static let monthly2Macs = "pri_01kqh0drp76rk3czdsm8yx6pq1" // $6.99/mo
        // Yearly
        static let yearly1Mac = "pri_01kqh0ds379rf0bwhfpm5khpyp"    // $24.99/yr
        static let yearly2Macs = "pri_01kqh0dsc8h86j4gr988y8ne3k"  // $39.99/yr
        // Lifetime
        static let lifetime1Mac = "pri_01kqh0dsk3tmkzaqgnsghdbwcr"  // $44.99
        static let lifetime2Macs = "pri_01kqh0dsswdf5fbpfnfm0f0acf" // $59.99
    }
    
    // Hosted Checkout URLs (pre-created in Paddle Dashboard)
    static let sandboxCheckoutURL = "https://sandbox-pay.paddle.io/hsc_01kqgtgmydc78z2xpzprbcpmmq_xkpvjdzdq0z0k12jbnjsdhfpntjga132"
    static let productionCheckoutURL = "" // Create in production dashboard when going live
    
    // Website pricing page
    static let websitePricingURL = "https://macbroom.com#pricing"
}

// MARK: - Paddle API Responses

// Create transaction response
struct PaddleCreateTransactionResponse: Codable {
    let data: PaddleTransaction?
    let error: PaddleApiError?
}

struct PaddleTransaction: Codable {
    let id: String
    let status: String
    let checkout: PaddleCheckout?
    let customData: [String: String]?
    let customerId: String?
    let customerName: String?
    let email: String?
    let billing: PaddleBilling?
    
    enum CodingKeys: String, CodingKey {
        case id, status, checkout, billing, email
        case customData = "custom_data"
        case customerId = "customer_id"
        case customerName = "customer_name"
    }
}

struct PaddleCheckout: Codable {
    let url: String?
}

struct PaddleBilling: Codable {
    let paymentMethod: String?
    
    enum CodingKeys: String, CodingKey {
        case paymentMethod = "payment_method"
    }
}

// Get transaction response (reuses same structure)
typealias PaddleGetTransactionResponse = PaddleCreateTransactionResponse

// Generic error
struct PaddleApiError: Codable {
    let code: Int?
    let detail: String?
    let message: String?
}

// MARK: - Paddle Service
class PaddleService {
    static let shared = PaddleService()
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Open Checkout in Browser
    /// Opens the MacBroom website pricing page — user chooses plan and pays there
    func openCheckout() {
        guard let url = URL(string: PaddleConfig.websitePricingURL) else {
            print("Paddle: Invalid pricing URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Verify Transaction
    /// Verify a completed Paddle transaction by transaction ID
    func verifyTransaction(transactionId: String) async throws -> LicenseInfo {
        let url = URL(string: "\(PaddleConfig.apiBase)/transactions/\(transactionId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(PaddleConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaddleError.internalError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            if let errorBody = try? JSONDecoder().decode(PaddleGetTransactionResponse.self, from: data),
               let error = errorBody.error {
                throw PaddleError.internalError(error.detail ?? error.message ?? "HTTP \(httpResponse.statusCode)")
            }
            throw PaddleError.internalError("HTTP \(httpResponse.statusCode)")
        }
        
        let result = try JSONDecoder().decode(PaddleGetTransactionResponse.self, from: data)
        
        guard let transaction = result.data else {
            throw PaddleError.internalError("No transaction data")
        }
        
        // Check if transaction is completed or ready
        let validStatuses = ["completed", "paid", "billed"]
        let isValid = validStatuses.contains(transaction.status)
        
        if !isValid && transaction.status == "ready" {
            // Transaction was created but not yet paid — still allow activation for sandbox testing
            // In production, you'd want to require "completed" status
        }
        
        let info = LicenseInfo(
            isValid: isValid || (PaddleConfig.isSandbox && transaction.status == "ready"),
            plan: "pro",
            billingCycle: "lifetime",
            deviceLimit: 1,
            email: transaction.email ?? "",
            expiresAt: nil, // One-time purchase = lifetime
            message: isValid ? nil : "Transaction status: \(transaction.status)"
        )
        
        return info
    }
    
    // MARK: - Activate with Transaction ID
    func activateWithTransactionId(_ transactionId: String) async throws -> LicenseInfo {
        let trimmedId = transactionId.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await verifyTransaction(transactionId: trimmedId)
    }
    
    // MARK: - Check Pending Transaction
    /// Check if there's a pending transaction from a previous checkout
    func checkPendingTransaction() async throws -> LicenseInfo? {
        guard let pendingTx = UserDefaults.standard.string(forKey: "macbroom_pending_paddle_tx") else {
            return nil
        }
        
        let info = try await verifyTransaction(transactionId: pendingTx)
        
        if info.isValid {
            // Clear pending
            UserDefaults.standard.removeObject(forKey: "macbroom_pending_paddle_tx")
            return info
        }
        
        return nil
    }
    
    // MARK: - Open Order Lookup
    func openOrderLookup() {
        // Paddle doesn't have a public order lookup page in the new billing system
        // Instead, direct users to their email for the transaction ID
        if let url = URL(string: "https://my.paddle.com/orders") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Paddle Errors
enum PaddleError: LocalizedError {
    case internalError(String)
    
    var errorDescription: String? {
        switch self {
        case .internalError(let msg): return msg
        }
    }
}
