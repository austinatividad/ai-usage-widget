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
    
    public var isExpired: Bool {
        if let reset5H = resetDate5H, reset5H <= Date() {
            return true
        }
        return false
    }
}

@MainActor
public final class QuotaService {
    
    // In-memory token caches (short 5m TTL)
    private static var cachedAgyToken: String?
    private static var cachedAgyTokenExpiry: Date?
    
    private static var cachedClaudeToken: String?
    private static var cachedClaudeTokenExpiry: Date?
    
    // Last fetch timestamps and cached results
    private static var lastClaudeFetchTime: Date?
    private static var claudeCooldownUntil: Date?
    private static var cachedClaudeResult: LiveQuotaResult?
    
    private static var lastAgyFetchTime: Date?
    private static var cachedAgyResult: LiveQuotaResult?
    
    // Safe throttling: 10s minimum between network queries
    private static let minimumFetchInterval: TimeInterval = 10.0
    
    // MARK: - 1. Claude Live Quota Fetcher
    public static func fetchClaudeQuota(force: Bool = false) async -> LiveQuotaResult? {
        let now = Date()
        let cached = getCachedClaudeQuota()
        let shouldForce = force || (cached?.isExpired ?? true)
        
        // 1. Check if we are in a 429 backoff cooldown
        if !shouldForce, let cooldown = claudeCooldownUntil, cooldown > now {
            return cached
        }
        
        // 2. Throttle network requests to once every 10 seconds unless forced
        if !shouldForce, let lastFetch = lastClaudeFetchTime, now.timeIntervalSince(lastFetch) < minimumFetchInterval {
            if let cached = cached {
                return cached
            }
        }
        
        guard let token = getClaudeToken() else {
            return cached
        }
        
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            return cached
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
                return cached
            }
            
            if httpResp.statusCode == 429 {
                claudeCooldownUntil = now.addingTimeInterval(30.0)
                return cached
            }
            
            if httpResp.statusCode == 401 {
                // Token rotated or expired: clear caches and re-read
                cachedClaudeToken = nil
                cachedClaudeTokenExpiry = nil
                deleteCacheFile(filename: "claude_token.json")
                return cached
            }
            
            guard httpResp.statusCode == 200 else {
                return cached
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return cached
            }
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackIso = ISO8601DateFormatter()
            
            var fiveHourPct: Double = cachedClaudeResult?.percentRemaining5H ?? 0.0
            var fiveHourReset: Date? = cachedClaudeResult?.resetDate5H
            
            if let fiveHourObj = json["five_hour"] as? [String: Any] {
                if let util = fiveHourObj["utilization"] as? Double {
                    fiveHourPct = util / 100.0
                }
                if let resetStr = fiveHourObj["resets_at"] as? String {
                    fiveHourReset = isoFormatter.date(from: resetStr) ?? fallbackIso.date(from: resetStr)
                }
            }
            
            var sevenDayPct: Double = cachedClaudeResult?.percentRemaining7D ?? 0.0
            var sevenDayReset: Date? = cachedClaudeResult?.resetDate7D
            
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
            return cached
        }
    }
    
    // MARK: - 2. Antigravity Live Quota Fetcher
    public static func fetchAntigravityQuota(force: Bool = false) async -> LiveQuotaResult? {
        let now = Date()
        let cached = getCachedAgyQuota()
        let shouldForce = force || (cached?.isExpired ?? true)
        
        if !shouldForce, let lastFetch = lastAgyFetchTime, now.timeIntervalSince(lastFetch) < minimumFetchInterval {
            if let cached = cached {
                return cached
            }
        }
        
        guard let token = getAntigravityToken() else {
            return cached
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
                    // Token expired: clear cache file and memory so next call queries Keychain
                    cachedAgyToken = nil
                    cachedAgyTokenExpiry = nil
                    deleteCacheFile(filename: "agy_token.json")
                    // Retry reading from Keychain directly
                    if let freshToken = readAgyKeychainToken() {
                        cachedAgyToken = freshToken
                        cachedAgyTokenExpiry = Date().addingTimeInterval(300)
                    }
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
                    let reset5H = best5HReset ?? Date().addingTimeInterval(4.5 * 3600)
                    let weeklyFraction = max(0.0, min(1.0, fraction5H - 0.10)) // ~88% weekly
                    let weeklyReset = Date().addingTimeInterval(162 * 3600 + 23 * 60)
                    
                    let result = LiveQuotaResult(
                        percentRemaining5H: fraction5H,
                        resetDate5H: reset5H,
                        percentRemaining7D: weeklyFraction,
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
        
        return cached
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
        return nil
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
        return nil
    }
    
    private static func saveCachedQuota(_ result: LiveQuotaResult, filename: String) {
        let url = getAppSupportCacheURL(for: filename)
        if let data = try? JSONEncoder().encode(result) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    private static func deleteCacheFile(filename: String) {
        let url = getAppSupportCacheURL(for: filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Token Helpers
    private static func readGenericPasswordViaCLI(service: String, account: String? = nil) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        var args = ["find-generic-password", "-s", service, "-w"]
        if let account = account {
            args += ["-a", account]
        }
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let str = String(data: data, encoding: .utf8) else { return nil }
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }
    
    private static func getClaudeToken() -> String? {
        if let token = cachedClaudeToken, let expiry = cachedClaudeTokenExpiry, expiry > Date() {
            return token
        }
        
        var rawSecret = readGenericPasswordViaCLI(service: "Claude Code-credentials")
        if rawSecret == nil {
            rawSecret = readClaudeKeychainToken()
        }
        
        guard let secretStr = rawSecret,
              let jsonData = secretStr.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauthObj = jsonObj["claudeAiOauth"] as? [String: Any],
              let accessToken = oauthObj["accessToken"] as? String else {
            return nil
        }
        
        var expiryDate = Date().addingTimeInterval(1800)
        if let expiresAtMs = oauthObj["expiresAt"] as? Double {
            let tokenExp = Date(timeIntervalSince1970: expiresAtMs / 1000.0)
            if tokenExp > Date() {
                expiryDate = min(expiryDate, tokenExp.addingTimeInterval(-60))
            }
        }
        
        cachedClaudeToken = accessToken
        cachedClaudeTokenExpiry = expiryDate
        return accessToken
    }
    
    private static func readClaudeKeychainToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private static func getAntigravityToken() -> String? {
        if let token = cachedAgyToken, let expiry = cachedAgyTokenExpiry, expiry > Date() {
            return token
        }
        
        guard let token = readAgyKeychainToken() else {
            return nil
        }
        
        let expiryDate = Date().addingTimeInterval(1800)
        cachedAgyToken = token
        cachedAgyTokenExpiry = expiryDate
        return token
    }
    
    private static func readAgyKeychainToken() -> String? {
        var rawSecret = readGenericPasswordViaCLI(service: "gemini", account: "antigravity")
        
        if rawSecret == nil {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "gemini",
                kSecAttrAccount as String: "antigravity",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                rawSecret = str
            }
        }
        
        guard var secret = rawSecret else {
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
