import Foundation
import SwiftUI

public enum WidgetDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case standard = "standard"
    case inline = "inline"
    case microStack = "microStack"
    case hoverExpand = "hoverExpand"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .inline:
            return "Compact Inline"
        case .microStack:
            return "Micro Stack"
        case .hoverExpand:
            return "Hover Expand"
        }
    }
    
    public var description: String {
        switch self {
        case .standard:
            return "Full view with dual rows, progress bars, and countdown timers."
        case .inline:
            return "Single-line horizontal rows with dual micro-bars."
        case .microStack:
            return "Ultra-narrow vertical layout for screen corners."
        case .hoverExpand:
            return "Compact by default; expands to Standard on mouse hover."
        }
    }
}

public enum QuotaFormat: Sendable, Equatable {
    case percentUsed       // Claude/Codex style: e.g. 0% used, 24% used
    case percentRemaining  // Antigravity style: e.g. 81% remaining, 97% remaining
}

public struct WindowUsage: Sendable, Equatable {
    public let label: String
    public let progress: Double // 0.0 ... 1.0
    public let percentageText: String
    public let resetDate: Date?
    public let formattedCountdown: String

    public init(
        label: String,
        progress: Double,
        format: QuotaFormat,
        resetDate: Date?,
        customCountdown: String? = nil
    ) {
        self.label = label
        let clamped = min(1.0, max(0.0, progress))
        self.progress = clamped
        
        let pct = Int(round(clamped * 100))
        self.percentageText = "\(pct)%"
        self.resetDate = resetDate
        
        if let customCountdown = customCountdown {
            self.formattedCountdown = customCountdown
        } else if let resetDate = resetDate {
            let remaining = resetDate.timeIntervalSinceNow
            if remaining <= 0 {
                self.formattedCountdown = "0M"
            } else {
                let totalSeconds = Int(remaining)
                let days = totalSeconds / 86400
                let hours = (totalSeconds % 86400) / 3600
                let minutes = (totalSeconds % 3600) / 60
                
                if days > 0 {
                    self.formattedCountdown = "\(days)D\(hours)H\(minutes)M"
                } else if hours > 0 {
                    self.formattedCountdown = "\(hours)H\(minutes)M"
                } else {
                    self.formattedCountdown = "\(minutes)M"
                }
            }
        } else {
            self.formattedCountdown = "0M"
        }
    }
}

public struct ProviderUsage: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let format: QuotaFormat
    public let summaryLabel: String
    public let activityStatus: ActivityStatus
    public let usage5H: WindowUsage
    public let usage7D: WindowUsage
    
    public init(
        id: String,
        name: String,
        format: QuotaFormat,
        summaryLabel: String,
        activityStatus: ActivityStatus,
        usage5H: WindowUsage,
        usage7D: WindowUsage
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.summaryLabel = summaryLabel
        self.activityStatus = activityStatus
        self.usage5H = usage5H
        self.usage7D = usage7D
    }
}
