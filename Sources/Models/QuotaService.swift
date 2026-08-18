import Foundation
import Security

public struct LiveQuotaResult: Sendable {
    public let percentRemaining5H: Double
    public let resetDate5H: Date?
    public let percentRemaining7D: Double
    public let resetDate7D: Date?
    
    public init(
        percentRemaining5H: Double,
        resetDate5H: Date?,
        percentRemaining7D: Double,
        resetDate7D: Date?
    ) {
        self.percentRemaining5H = percentRemaining5H
        self.resetDate5H = resetDate5H
        self.percentRemaining7D = percentRemaining7D
        self.resetDate7D = resetDate7D
    }
}

@MainActor
public final class QuotaService {
    
    // In-memory token caches
    private static var cachedAgyToken: String?
    private static var cachedAgyTokenExpiry: Date?
    
    private static var cachedClaudeToken: String?
    private static var cachedClaudeTokenExpiry: Date?
    
    // MARK: - 1. Claude Live Quota Fetcher
    public static func fetchClaudeQuota() async -> LiveQuotaResult? {
        guard let token = getClaudeToken() else {
            return nil
        }
        
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("claude-code", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                return nil
            }
            
            if httpResp.statusCode == 401 {
                cachedClaudeToken = nil
                cachedClaudeTokenExpiry = nil
                return nil
            }
            
            guard httpResp.statusCode == 200 else {
                return nil
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackIso = ISO8601DateFormatter()
            
            var fiveHourPct: Double = 0.0
            var fiveHourReset: Date?
            
            if let fiveHourObj = json["five_hour"] as? [String: Any] {
                if let util = fiveHourObj["utilization"] as? Double {
                    fiveHourPct = util / 100.0
                }
                if let resetStr = fiveHourObj["resets_at"] as? String {
                    fiveHourReset = isoFormatter.date(from: resetStr) ?? fallbackIso.date(from: resetStr)
                }
            }
            
            var sevenDayPct: Double = 0.0
            var sevenDayReset: Date?
            
            if let sevenDayObj = json["seven_day"] as? [String: Any] {
                if let util = sevenDayObj["utilization"] as? Double {
                    sevenDayPct = util / 100.0
                }
                if let resetStr = sevenDayObj["resets_at"] as? String {
                    sevenDayReset = isoFormatter.date(from: resetStr) ?? fallbackIso.date(from: resetStr)
                }
            }
            
            return LiveQuotaResult(
                percentRemaining5H: max(0.0, min(1.0, fiveHourPct)),
                resetDate5H: fiveHourReset,
                percentRemaining7D: max(0.0, min(1.0, sevenDayPct)),
                resetDate7D: sevenDayReset
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - 2. Antigravity Live Quota Fetcher
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
                    cachedAgyToken = nil
                    cachedAgyTokenExpiry = nil
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
    
    // MARK: - Token Helpers
    private static func getClaudeToken() -> String? {
        if let token = cachedClaudeToken, let expiry = cachedClaudeTokenExpiry, expiry > Date() {
            return token
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        
        guard let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauthObj = jsonObj["claudeAiOauth"] as? [String: Any],
              let accessToken = oauthObj["accessToken"] as? String else {
            return nil
        }
        
        let expiryDate = Date().addingTimeInterval(3000)
        cachedClaudeToken = accessToken
        cachedClaudeTokenExpiry = expiryDate
        return accessToken
    }
    
    private static func getAntigravityToken() -> String? {
        // 1. Check in-memory cache
        if let token = cachedAgyToken, let expiry = cachedAgyTokenExpiry, expiry > Date() {
            return token
        }
        
        // 2. Check persistent app support storage cache
        let cacheFileURL = getAppSupportCacheURL(for: "agy_token.json")
        if let fileData = try? Data(contentsOf: cacheFileURL),
           let cacheJson = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any],
           let savedToken = cacheJson["access_token"] as? String,
           let expirySec = cacheJson["expiry_time"] as? TimeInterval {
            let expiryDate = Date(timeIntervalSince1970: expirySec)
            if expiryDate > Date() {
                cachedAgyToken = savedToken
                cachedAgyTokenExpiry = expiryDate
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
        cachedAgyToken = accessToken
        cachedAgyTokenExpiry = expiryDate
        
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
    
    private static func getAppSupportCacheURL(for filename: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.ity.tacho", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent(filename)
    }
}
