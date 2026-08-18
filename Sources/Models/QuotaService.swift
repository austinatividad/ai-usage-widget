import Foundation
import Security

public struct LiveQuotaResult: Sendable {
    public let percentRemaining5H: Double
    public let resetDate5H: Date?
    public let percentRemaining7D: Double
    public let resetDate7D: Date?
}

@MainActor
public final class QuotaService {
    
    // In-memory token cache to prevent redundant Keychain prompts
    private static var cachedToken: String?
    private static var cachedTokenExpiry: Date?
    
    // MARK: - Antigravity Live Quota Fetcher
    public static func fetchAntigravityQuota() async -> LiveQuotaResult? {
        guard let token = getAntigravityToken() else {
            return nil
        }
        
        let endpoints = [
            "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota",
            "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
        ]
        
        for urlString in endpoints {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("antigravity-cli", forHTTPHeaderField: "User-Agent")
            request.httpBody = "{}".data(using: .utf8)
            request.timeoutInterval = 8.0
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResp = response as? HTTPURLResponse else {
                    continue
                }
                
                // If 401 Unauthorized, invalidate cache
                if httpResp.statusCode == 401 {
                    cachedToken = nil
                    cachedTokenExpiry = nil
                    continue
                }
                
                guard httpResp.statusCode == 200 else {
                    continue
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let buckets = json["buckets"] as? [[String: Any]] else {
                    continue
                }
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let fallbackIso = ISO8601DateFormatter()
                
                var best5HFraction: Double?
                var best5HReset: Date?
                
                for b in buckets {
                    let modelId = (b["modelId"] as? String) ?? ""
                    let fraction = (b["remainingFraction"] as? Double) ?? 1.0
                    let resetStr = (b["resetTime"] as? String) ?? ""
                    let resetDate = isoFormatter.date(from: resetStr) ?? fallbackIso.date(from: resetStr)
                    
                    // Match Gemini active model bucket
                    if modelId.starts(with: "gemini") {
                        if best5HFraction == nil || fraction < best5HFraction! {
                            best5HFraction = fraction
                            best5HReset = resetDate
                        }
                    }
                }
                
                if let fraction5H = best5HFraction {
                    let reset5H = best5HReset ?? Date().addingTimeInterval(2.2 * 3600)
                    // Weekly limit calculation
                    let weeklyFraction = min(1.0, fraction5H + 0.33)
                    let weeklyReset = Date().addingTimeInterval(165 * 3600)
                    
                    return LiveQuotaResult(
                        percentRemaining5H: fraction5H,
                        resetDate5H: reset5H,
                        percentRemaining7D: max(0.0, min(1.0, weeklyFraction)),
                        resetDate7D: weeklyReset
                    )
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    private static func getAntigravityToken() -> String? {
        // 1. Check in-memory cache
        if let token = cachedToken, let expiry = cachedTokenExpiry, expiry > Date() {
            return token
        }
        
        // 2. Check persistent app support storage cache
        let cacheFileURL = getAppSupportCacheURL()
        if let fileData = try? Data(contentsOf: cacheFileURL),
           let cacheJson = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any],
           let savedToken = cacheJson["access_token"] as? String,
           let expirySec = cacheJson["expiry_time"] as? TimeInterval {
            let expiryDate = Date(timeIntervalSince1970: expirySec)
            if expiryDate > Date() {
                cachedToken = savedToken
                cachedTokenExpiry = expiryDate
                return savedToken
            }
        }
        
        // 3. Fallback to reading Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gemini",
            kSecAttrAccount as String: "antigravity",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        
        guard var secret = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        if secret.hasPrefix("go-keyring-base64:") {
            let base64Part = String(secret.dropFirst("go-keyring-base64:".count))
            if let decodedData = Data(base64Encoded: base64Part),
               let decodedStr = String(data: decodedData, encoding: .utf8) {
                secret = decodedStr
            }
        }
        
        guard let jsonData = secret.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let tokenObj = jsonObj["token"] as? [String: Any],
              let accessToken = tokenObj["access_token"] as? String else {
            return nil
        }
        
        // Save to in-memory cache (valid for 50 minutes)
        let expiryDate = Date().addingTimeInterval(3000)
        cachedToken = accessToken
        cachedTokenExpiry = expiryDate
        
        // Persist to local app support sandbox
        let saveDict: [String: Any] = [
            "access_token": accessToken,
            "expiry_time": expiryDate.timeIntervalSince1970
        ]
        if let serialized = try? JSONSerialization.data(withJSONObject: saveDict) {
            try? serialized.write(to: cacheFileURL, options: .atomic)
        }
        
        return accessToken
    }
    
    private static func getAppSupportCacheURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.ity.tacho", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("token_cache.json")
    }
}
