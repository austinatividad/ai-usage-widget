import Foundation
import Combine
import Security

@MainActor
public final class UsageTracker: ObservableObject {
    @Published public private(set) var claudeUsage: ProviderUsage
    @Published public private(set) var antigravityUsage: ProviderUsage
    @Published public private(set) var isRefreshing: Bool = false
    
    private var timer: Timer?
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
    private var agy5HPercentRemaining: Double = 0.8129
    private var agy7DPercentRemaining: Double = 0.9664

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
        
        self.agy5HReset = now.addingTimeInterval(3 * 3600 + 29 * 60)
        self.agyWeekReset = now.addingTimeInterval(166 * 3600 + 29 * 60)
        
        let claudeStatus = SessionDetector.detectClaudeStatus()
        let agyStatus = SessionDetector.detectAntigravityStatus()
        
        self.claudeUsage = ProviderUsage(
            id: "claude",
            name: "Claude Code",
            format: .percentUsed,
            summaryLabel: "0% used",
            activityStatus: claudeStatus,
            usage5H: WindowUsage(label: "5H", progress: 0.0, format: .percentUsed, resetDate: c5hTarget),
            usage7D: WindowUsage(label: "7D", progress: 0.24, format: .percentUsed, resetDate: calendar.date(from: weekComp))
        )
        
        self.antigravityUsage = ProviderUsage(
            id: "antigravity",
            name: "Antigravity",
            format: .percentRemaining,
            summaryLabel: "81% rem",
            activityStatus: agyStatus,
            usage5H: WindowUsage(label: "5H", progress: 0.8129, format: .percentRemaining, resetDate: now.addingTimeInterval(3 * 3600 + 29 * 60)),
            usage7D: WindowUsage(label: "7D", progress: 0.9664, format: .percentRemaining, resetDate: now.addingTimeInterval(166 * 3600 + 29 * 60))
        )
        
        syncWithLocalActivity()
        startTimer()
        setupEventDrivenFileWatchers()
    }

    public func refresh() {
        isRefreshing = true
        syncWithLocalActivity()
        
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            self.isRefreshing = false
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
    }

    private func setupEventDrivenFileWatchers() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let pathsToWatch = [
            home.appendingPathComponent(".claude/sessions").path,
            home.appendingPathComponent(".claude").path,
            home.appendingPathComponent(".gemini/antigravity-cli/conversations").path,
            home.appendingPathComponent(".gemini/antigravity-cli/presence").path,
            home.appendingPathComponent(".gemini/antigravity-cli").path
        ]
        
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
        
        recomputeWindows()
    }

    private func recomputeWindows() {
        let claudeStatus = SessionDetector.detectClaudeStatus()
        let agyStatus = SessionDetector.detectAntigravityStatus()
        
        // 1. Claude Code
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
        
        let newClaudeUsage = ProviderUsage(
            id: "claude",
            name: "Claude Code",
            format: .percentUsed,
            summaryLabel: "\(Int(round(claude7DPercentUsed * 100)))% used",
            activityStatus: claudeStatus,
            usage5H: c5hUsage,
            usage7D: c7dUsage
        )
        
        if self.claudeUsage != newClaudeUsage {
            self.claudeUsage = newClaudeUsage
        }
        
        // 2. Antigravity
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
        
        let newAgyUsage = ProviderUsage(
            id: "antigravity",
            name: "Antigravity",
            format: .percentRemaining,
            summaryLabel: "\(Int(round(agy5HPercentRemaining * 100)))% rem",
            activityStatus: agyStatus,
            usage5H: a5hUsage,
            usage7D: a7dUsage
        )
        
        if self.antigravityUsage != newAgyUsage {
            self.antigravityUsage = newAgyUsage
        }
    }
}
