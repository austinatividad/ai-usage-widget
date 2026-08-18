import Foundation
import SwiftUI

public protocol AIProvider: Sendable, Identifiable {
    var id: String { get }
    var displayName: String { get }
    var quotaFormat: QuotaFormat { get }
    var accentColor: Color { get }
    var monitoredPaths: [String] { get }
    var isInstalledOnSystem: Bool { get }
    
    @MainActor
    func makeIconView(size: CGFloat) -> AnyView
    
    func fetchLiveQuota() async -> LiveQuotaResult?
    func detectSessionStatus() -> ActivityStatus
}

// MARK: - 1. Claude Provider
public struct ClaudeProvider: AIProvider {
    public let id: String = "claude"
    public let displayName: String = "Claude Code"
    public let quotaFormat: QuotaFormat = .percentUsed
    public let accentColor: Color = .white
    
    public init() {}
    
    public var isInstalledOnSystem: Bool {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
        return FileManager.default.fileExists(atPath: path)
    }
    
    public var monitoredPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".claude/sessions").path,
            home.appendingPathComponent(".claude/projects").path,
            home.appendingPathComponent(".claude").path
        ]
    }
    
    @MainActor
    public func makeIconView(size: CGFloat) -> AnyView {
        AnyView(ClaudeIconView(size: size))
    }
    
    public func fetchLiveQuota() async -> LiveQuotaResult? {
        await QuotaService.fetchClaudeQuota()
    }
    
    public func detectSessionStatus() -> ActivityStatus {
        SessionDetector.detectClaudeStatus()
    }
}

// MARK: - 2. Antigravity Provider
public struct AntigravityProvider: AIProvider {
    public let id: String = "antigravity"
    public let displayName: String = "Antigravity"
    public let quotaFormat: QuotaFormat = .percentRemaining
    public let accentColor: Color = Color(red: 142/255, green: 188/255, blue: 110/255)
    
    public init() {}
    
    public var isInstalledOnSystem: Bool {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/antigravity-cli").path
        return FileManager.default.fileExists(atPath: path)
    }
    
    public var monitoredPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".gemini/antigravity-cli/conversations").path,
            home.appendingPathComponent(".gemini/antigravity-cli/presence").path,
            home.appendingPathComponent(".gemini/antigravity-cli").path
        ]
    }
    
    @MainActor
    public func makeIconView(size: CGFloat) -> AnyView {
        AnyView(AntigravityIconView(size: size))
    }
    
    public func fetchLiveQuota() async -> LiveQuotaResult? {
        await QuotaService.fetchAntigravityQuota()
    }
    
    public func detectSessionStatus() -> ActivityStatus {
        SessionDetector.detectAntigravityStatus()
    }
}

// MARK: - 3. Codex Provider
public struct CodexProvider: AIProvider {
    public let id: String = "codex"
    public let displayName: String = "Codex CLI"
    public let quotaFormat: QuotaFormat = .percentUsed
    public let accentColor: Color = Color(red: 16/255, green: 163/255, blue: 127/255)
    
    public init() {}
    
    public var isInstalledOnSystem: Bool {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path
        return FileManager.default.fileExists(atPath: path)
    }
    
    public var monitoredPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".codex/process_manager").path,
            home.appendingPathComponent(".codex/sessions").path,
            home.appendingPathComponent(".codex").path
        ]
    }
    
    @MainActor
    public func makeIconView(size: CGFloat) -> AnyView {
        AnyView(CodexIconView(size: size))
    }
    
    public func fetchLiveQuota() async -> LiveQuotaResult? {
        return nil
    }
    
    public func detectSessionStatus() -> ActivityStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let pmFile = home.appendingPathComponent(".codex/process_manager/chat_processes.json").path
        let walFile = home.appendingPathComponent(".codex/logs_2.sqlite-wal").path
        
        guard FileManager.default.fileExists(atPath: pmFile) else {
            return isInstalledOnSystem ? .idle(sessionCount: 1) : .inactive
        }
        
        var totalAlive = 0
        var isActive = false
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: pmFile)),
           let processes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for p in processes {
                if let pid = p["pid"] as? Int, kill(pid_t(pid), 0) == 0 {
                    totalAlive += 1
                }
            }
        }
        
        if let walAttrs = try? FileManager.default.attributesOfItem(atPath: walFile),
           let walMod = walAttrs[.modificationDate] as? Date {
            if Date().timeIntervalSince(walMod) < 2.5 {
                isActive = true
            }
        }
        
        if totalAlive == 0 && !isActive {
            return isInstalledOnSystem ? .idle(sessionCount: 1) : .inactive
        }
        
        if isActive {
            return .active(activeCount: max(1, totalAlive), total: max(1, totalAlive))
        }
        
        return .idle(sessionCount: max(1, totalAlive))
    }
}

// MARK: - Provider Registry
@MainActor
public final class ProviderRegistry: ObservableObject {
    public static let shared = ProviderRegistry()
    
    public let allProviders: [any AIProvider] = [
        ClaudeProvider(),
        AntigravityProvider(),
        CodexProvider()
    ]
    
    private let enabledKey = "AIUsageWidget_EnabledProviders"
    
    @Published public var enabledProviderIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledProviderIds), forKey: enabledKey)
        }
    }
    
    public init() {
        if let saved = UserDefaults.standard.stringArray(forKey: enabledKey) {
            self.enabledProviderIds = Set(saved)
        } else {
            // Default: enable all installed providers on system
            let installed = allProviders.filter { $0.isInstalledOnSystem }.map { $0.id }
            self.enabledProviderIds = Set(installed.isEmpty ? ["claude", "antigravity", "codex"] : installed)
        }
    }
    
    public func isEnabled(id: String) -> Bool {
        enabledProviderIds.contains(id)
    }
    
    public func setEnabled(id: String, enabled: Bool) {
        if enabled {
            enabledProviderIds.insert(id)
        } else {
            // Ensure at least one provider remains enabled
            if enabledProviderIds.count > 1 {
                enabledProviderIds.remove(id)
            }
        }
    }
}
