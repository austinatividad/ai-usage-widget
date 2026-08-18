import Foundation
import Combine
import Security

@MainActor
public final class UsageTracker: ObservableObject {
    @Published public private(set) var activeProviders: [ProviderUsage] = []
    @Published public private(set) var isRefreshing: Bool = false
    
    public let registry = ProviderRegistry.shared
    
    private var timer: Timer?
    private var quotaTimer: Timer?
    private var fileWatchers: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var debounceTask: Task<Void, Never>?

    // Stored/Synced anchor points
    private var claudeSessionReset: Date
    private var claudeWeekReset: Date
    private var claude5HPercentUsed: Double = 0.00
    private var claude7DPercentUsed: Double = 0.24
    
    private var agy5HReset: Date
    private var agyWeekReset: Date
    private var agy5HPercentRemaining: Double = 0.6033
    private var agy7DPercentRemaining: Double = 0.9308
    
    private var codex5HReset: Date
    private var codexWeekReset: Date
    private var codex5HPercentUsed: Double = 0.08
    private var codex7DPercentUsed: Double = 0.35

    public var widgetHeight: CGFloat {
        let count = max(1, activeProviders.count)
        return CGFloat(32 + (54 * count) + (12 * (count - 1)))
    }

    public init() {
        let now = Date()
        let calendar = Calendar.current
        
        var comp = calendar.dateComponents([.year, .month, .day], from: now)
        comp.hour = 0
        comp.minute = 30
        comp.second = 0
        var c5hTarget = calendar.date(from: comp) ?? now.addingTimeInterval(3.5 * 3600)
        if c5hTarget <= now {
            c5hTarget = c5hTarget.addingTimeInterval(24 * 3600)
        }
        self.claudeSessionReset = c5hTarget
        
        var weekComp = calendar.dateComponents([.year, .month], from: now)
        weekComp.day = 21
        weekComp.hour = 23
        weekComp.minute = 0
        weekComp.second = 0
        self.claudeWeekReset = calendar.date(from: weekComp) ?? now.addingTimeInterval(75 * 3600)
        
        self.agy5HReset = now.addingTimeInterval(2 * 3600 + 12 * 60)
        self.agyWeekReset = now.addingTimeInterval(165 * 3600 + 12 * 60)
        
        self.codex5HReset = now.addingTimeInterval(4 * 3600 + 45 * 60)
        self.codexWeekReset = now.addingTimeInterval(140 * 3600)
        
        recomputeWindows()
        startTimer()
        setupEventDrivenFileWatchers()
        
        if UserDefaults.standard.bool(forKey: "AIUsageWidget_HasCompletedOnboarding") {
            fetchLiveQuotasAsync()
        }
    }

    public func refresh() {
        isRefreshing = true
        fetchLiveQuotasAsync()
        syncWithLocalActivity()
        
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            self.isRefreshing = false
        }
    }

    public func fetchLiveQuotas() {
        fetchLiveQuotasAsync()
    }

    public func updateEnabledProviders() {
        recomputeWindows()
        setupEventDrivenFileWatchers()
    }

    private func fetchLiveQuotasAsync() {
        Task {
            if let agyResult = await QuotaService.fetchAntigravityQuota() {
                self.agy5HPercentRemaining = agyResult.percentRemaining5H
                if let r5h = agyResult.resetDate5H {
                    self.agy5HReset = r5h
                }
                self.agy7DPercentRemaining = agyResult.percentRemaining7D
                if let r7d = agyResult.resetDate7D {
                    self.agyWeekReset = r7d
                }
                self.recomputeWindows()
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recomputeWindows()
            }
        }
        t.tolerance = 0.15
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
        
        // Quota background sync every 60s
        quotaTimer?.invalidate()
        let qt = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                if UserDefaults.standard.bool(forKey: "AIUsageWidget_HasCompletedOnboarding") {
                    self?.fetchLiveQuotasAsync()
                }
            }
        }
        qt.tolerance = 5.0
        RunLoop.main.add(qt, forMode: .common)
        self.quotaTimer = qt
    }

    private func setupEventDrivenFileWatchers() {
        // Clear existing watchers
        for w in fileWatchers {
            w.cancel()
        }
        fileWatchers.removeAll()
        for fd in fileDescriptors {
            close(fd)
        }
        fileDescriptors.removeAll()
        
        var pathsToWatch: Set<String> = []
        for provider in registry.allProviders where registry.isEnabled(id: provider.id) {
            for path in provider.monitoredPaths {
                if FileManager.default.fileExists(atPath: path) {
                    pathsToWatch.insert(path)
                }
            }
        }
        
        for path in pathsToWatch {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            fileDescriptors.append(fd)
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .attrib, .link],
                queue: DispatchQueue.main
            )
            
            source.setEventHandler { [weak self] in
                self?.handleFileEvent()
            }
            
            source.setCancelHandler {
                close(fd)
            }
            
            source.resume()
            fileWatchers.append(source)
        }
    }

    private func handleFileEvent() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000) // 80ms event coalescing
            if !Task.isCancelled {
                self?.syncWithLocalActivity()
                if UserDefaults.standard.bool(forKey: "AIUsageWidget_HasCompletedOnboarding") {
                    self?.fetchLiveQuotasAsync()
                }
            }
        }
    }

    private func syncWithLocalActivity() {
        let now = Date()
        
        if claudeSessionReset <= now {
            claudeSessionReset = now.addingTimeInterval(5 * 3600)
        }
        if agy5HReset <= now {
            agy5HReset = now.addingTimeInterval(5 * 3600)
        }
        if codex5HReset <= now {
            codex5HReset = now.addingTimeInterval(5 * 3600)
        }
        
        recomputeWindows()
    }

    private func recomputeWindows() {
        var computed: [ProviderUsage] = []
        
        for provider in registry.allProviders where registry.isEnabled(id: provider.id) {
            let status = provider.detectSessionStatus()
            
            switch provider.id {
            case "claude":
                let c5hUsage = WindowUsage(
                    label: "5H",
                    progress: claude5HPercentUsed,
                    format: .percentUsed,
                    resetDate: claudeSessionReset
                )
                let c7dUsage = WindowUsage(
                    label: "7D",
                    progress: claude7DPercentUsed,
                    format: .percentUsed,
                    resetDate: claudeWeekReset
                )
                computed.append(ProviderUsage(
                    id: "claude",
                    name: provider.displayName,
                    format: .percentUsed,
                    summaryLabel: "\(Int(round(claude7DPercentUsed * 100)))% used",
                    activityStatus: status,
                    usage5H: c5hUsage,
                    usage7D: c7dUsage
                ))
                
            case "antigravity":
                let a5hUsage = WindowUsage(
                    label: "5H",
                    progress: agy5HPercentRemaining,
                    format: .percentRemaining,
                    resetDate: agy5HReset
                )
                let a7dUsage = WindowUsage(
                    label: "7D",
                    progress: agy7DPercentRemaining,
                    format: .percentRemaining,
                    resetDate: agyWeekReset
                )
                computed.append(ProviderUsage(
                    id: "antigravity",
                    name: provider.displayName,
                    format: .percentRemaining,
                    summaryLabel: "\(Int(round(agy5HPercentRemaining * 100)))% rem",
                    activityStatus: status,
                    usage5H: a5hUsage,
                    usage7D: a7dUsage
                ))
                
            case "codex":
                let x5hUsage = WindowUsage(
                    label: "5H",
                    progress: codex5HPercentUsed,
                    format: .percentUsed,
                    resetDate: codex5HReset
                )
                let x7dUsage = WindowUsage(
                    label: "7D",
                    progress: codex7DPercentUsed,
                    format: .percentUsed,
                    resetDate: codexWeekReset
                )
                computed.append(ProviderUsage(
                    id: "codex",
                    name: provider.displayName,
                    format: .percentUsed,
                    summaryLabel: "\(Int(round(codex7DPercentUsed * 100)))% used",
                    activityStatus: status,
                    usage5H: x5hUsage,
                    usage7D: x7dUsage
                ))
                
            default:
                break
            }
        }
        
        if self.activeProviders != computed {
            self.activeProviders = computed
        }
    }
}
