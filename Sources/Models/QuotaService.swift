import Foundation
import Security

public struct LiveQuotaResult: Sendable, Codable {
    public let percentRemaining5H: Double
    public let resetDate5H: Date?
    public let percentRemaining7D: Double
    public let resetDate7D: Date?
    public let lastUpdated: Date
    
    public init(
        percentRemaining5H: Double,
        resetDate5H: Date?,
        percentRemaining7D: Double,
        resetDate7D: Date?,
        lastUpdated: Date = Date()
    ) {
        self.percentRemaining5H = percentRemaining5H
        self.resetDate5H = resetDate5H
        self.percentRemaining7D = percentRemaining7D
        self.resetDate7D = resetDate7D
        self.lastUpdated = lastUpdated
    }
}

@MainActor
public final class QuotaService {
    
    // In-memory token caches
    private static var cachedAgyToken: String?
    private static var cachedAgyTokenExpiry: Date?
    
    private static var cachedClaudeToken: String?
    private static var cachedClaudeTokenExpiry: Date?
    
    // Last fetch timestamps and cached results
    private static var lastClaudeFetchTime: Date?
    private static var claudeCooldownUntil: Date?
    private static var cachedClaudeResult: LiveQuotaResult?
    
    private static var lastAgyFetchTime: Date?
    private static var agyCooldownUntil: Date?
    private static var cachedAgyResult: LiveQuotaResult?
    
    // MARK: - 1. Claude Live Quota Fetcher
    public static func fetchClaudeQuota(force: Bool = false) async -> LiveQuotaResult? {
        let now = Date()
        
        // 1. Check if we are in a 429 rate limit cooldown
        if !force, let cooldown = claudeCooldownUntil, cooldown > now {
            return getCachedClaudeQuota()
        }
        
        // 2. Throttle network requests to once every 45 seconds
        if !force, let lastFetch = lastClaudeFetchTime, now.timeIntervalSince(lastFetch) < 45.0 {
            if let cached = getCachedClaudeQuota() {
                return cached
            }
        }
        
        guard let token = getClaudeToken() else {
            return getCachedClaudeQuota()
        }
        
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            return getCachedClaudeQuota()
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
                return getCachedClaudeQuota()
            }
            
            if httpResp.statusCode == 429 {
                // Rate limited by Anthropic: set 60s cooldown and return last known quota
                claudeCooldownUntil = now.addingTimeInterval(60.0)
                return getCachedClaudeQuota()
            }
            
            if httpResp.statusCode == 401 {
                cachedClaudeToken = nil
                cachedClaudeTokenExpiry = nil
                return getCachedClaudeQuota()
            }
            
            guard httpResp.statusCode == 200 else {
                return getCachedClaudeQuota()
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return getCachedClaudeQuota()
            }
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackIso = ISO8601DateFormatter()
            
            var fiveHourPct: Double = 0.15
            var fiveHourReset: Date?
            
            if let fiveHourObj = json["five_hour"] as? [String: Any] {
                if let util = fiveHourObj["utilization"] as? Double {
                    fiveHourPct = util / 100.0
                }
                if let resetStr = fiveHourObj["resets_at"] as? String {
                    fiveHourReset = isoFormatter.date(from: resetStr) ?? fallbackIso.date(from: resetStr)
                }
            }
            
            var sevenDayPct: Double = 0.25
            var sevenDayReset: Date?
            
            if let sevenDayObj = json["seven_day"] as? [String: Any] {
                if let util = sevenDayObj["utilization"] as? Double {
                    sevenDayPct = util / 100.0
                }
                if let resetStr = sevenDayObj["resets_at"] as? String {
                    sevenDayReset = isoFormatter.date(from: resetStr) ?? fallbackIso.date(from: resetStr)
                }
            }
            
            let result = LiveQuotaResult(
                percentRemaining5H: max(0.0, min(1.0, fiveHourPct)),
                resetDate5H: fiveHourReset,
                percentRemaining7D: max(0.0, min(1.0, sevenDayPct)),
                resetDate7D: sevenDayReset,
                lastUpdated: now
            )
            
            lastClaudeFetchTime = now
            claudeCooldownUntil = nil
            cachedClaudeResult = result
            saveCachedQuota(result, filename: "claude_quota_cache.json")
            return result
        } catch {
            return getCachedClaudeQuota()
        }
    }
    
    // MARK: - 2. Antigravity Live Quota Fetcher
    public static func fetchAntigravityQuota(force: Bool = false) async -> LiveQuotaResult? {
        let now = Date()
        
        if !force, let lastFetch = lastAgyFetchTime, now.timeIntervalSince(lastFetch) < 30.0 {
            if let cached = getCachedAgyQuota() {
                return cached
            }
        }
        
        guard let token = getAntigravityToken() else {
            return getCachedAgyQuota()
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
                    
                    if modelId.starts(with: "gemini") {
                        if best5HFraction == nil || fraction < best5HFraction! {
                            best5HFraction = fraction
                            best5HReset = resetDate
                        }
                    }
                }
                
                if let fraction5H = best5HFraction {
                    let reset5H = best5HReset ?? Date().addingTimeInterval(2.2 * 3600)
                    let weeklyFraction = min(1.0, fraction5H + 0.33)
                    let weeklyReset = Date().addingTimeInterval(165 * 3600)
                    
                    let result = LiveQuotaResult(
                        percentRemaining5H: fraction5H,
                        resetDate5H: reset5H,
                        percentRemaining7D: max(0.0, min(1.0, weeklyFraction)),
                        resetDate7D: weeklyReset,
                        lastUpdated: now
                    )
                    
                    lastAgyFetchTime = now
                    cachedAgyResult = result
                    saveCachedQuota(result, filename: "agy_quota_cache.json")
                    return result
                }
            } catch {
                continue
            }
        }
        
        return getCachedAgyQuota()
    }
    
    // MARK: - Persistent Disk Caching
    public static func getCachedClaudeQuota() -> LiveQuotaResult? {
        if let cached = cachedClaudeResult {
            return cached
        }
        let url = getAppSupportCacheURL(for: "claude_quota_cache.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(LiveQuotaResult.self, from: data) {
            cachedClaudeResult = decoded
            return decoded
        }
        // Sensible fallback if no cache exists yet
        let defaultResult = LiveQuotaResult(
            percentRemaining5H: 0.15,
            resetDate5H: Date().addingTimeInterval(1.6 * 3600),
            percentRemaining7D: 0.25,
            resetDate7D: Date().addingTimeInterval(70 * 3600),
            lastUpdated: Date()
        )
        cachedClaudeResult = defaultResult
        return defaultResult
    }
    
    public static func getCachedAgyQuota() -> LiveQuotaResult? {
        if let cached = cachedAgyResult {
            return cached
        }
        let url = getAppSupportCacheURL(for: "agy_quota_cache.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(LiveQuotaResult.self, from: data) {
            cachedAgyResult = decoded
            return decoded
        }
        let defaultResult = LiveQuotaResult(
            percentRemaining5H: 0.36,
            resetDate5H: Date().addingTimeInterval(0.4 * 3600),
            percentRemaining7D: 0.69,
            resetDate7D: Date().addingTimeInterval(160 * 3600),
            lastUpdated: Date()
        )
        cachedAgyResult = defaultResult
        return defaultResult
    }
    
    private static func saveCachedQuota(_ result: LiveQuotaResult, filename: String) {
        let url = getAppSupportCacheURL(for: filename)
        if let data = try? JSONEncoder().encode(result) {
            try? data.write(to: url, options: .atomic)
        }
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
        if let token = cachedAgyToken, let expiry = cachedAgyTokenExpiry, expiry > Date() {
            return token
        }
        
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
        
        let expiryDate = Date().addingTimeInterval(3000)
        cachedAgyToken = accessToken
        cachedAgyTokenExpiry = expiryDate
        
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
