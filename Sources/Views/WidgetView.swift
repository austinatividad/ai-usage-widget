import SwiftUI
import ServiceManagement

public struct WidgetContent: View {
    @ObservedObject var tracker: UsageTracker
    public var showRefresh: Bool = true
    @State private var spinRotation: Double = 0
    
    public init(tracker: UsageTracker, showRefresh: Bool = true) {
        self.tracker = tracker
        self.showRefresh = showRefresh
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Claude Code Section (% Used)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    ClaudeIconView(size: 14)
                    Text("Claude Code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    headerStatusBadge(usage: tracker.claudeUsage)
                }
                
                // 5H Row
                usageRow(usage: tracker.claudeUsage.usage5H, fillColor: .white)
                
                // 7D Row
                usageRow(usage: tracker.claudeUsage.usage7D, fillColor: .white)
            }
            
            // MARK: - Antigravity Section (% Remaining)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    AntigravityIconView(size: 14)
                    Text("Antigravity")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    headerStatusBadge(usage: tracker.antigravityUsage)
                }
                
                // 5H Row
                usageRow(usage: tracker.antigravityUsage.usage5H, fillColor: Color(red: 142/255, green: 188/255, blue: 110/255))
                
                // 7D Row
                usageRow(usage: tracker.antigravityUsage.usage7D, fillColor: Color(red: 142/255, green: 188/255, blue: 110/255))
            }
            
            if showRefresh {
                Spacer(minLength: 2)
                
                // MARK: - Bottom Controls
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            spinRotation += 360
                        }
                        tracker.refresh()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.7))
                            .rotationEffect(.degrees(spinRotation))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func headerStatusBadge(usage: ProviderUsage) -> some View {
        switch usage.activityStatus {
        case .needsResponse(let waiting, let total):
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 255/255, green: 159/255, blue: 10/255))
                    .frame(width: 6, height: 6)
                Text(total > 1 ? "Needs response (\(waiting))" : "Needs response")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(Color(red: 255/255, green: 159/255, blue: 10/255))
            }
        case .active(let active, let total):
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 48/255, green: 209/255, blue: 88/255))
                    .frame(width: 6, height: 6)
                Text(total > 1 ? "\(active) of \(total) Active" : "Active")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(Color(red: 48/255, green: 209/255, blue: 88/255))
            }
        case .idle(let count):
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(white: 0.45))
                    .frame(width: 5, height: 5)
                Text(count > 1 ? "\(count) Idle · \(usage.summaryLabel)" : "\(usage.summaryLabel)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
            }
        case .inactive:
            Text(usage.summaryLabel)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(usage.id == "claude" ? Color(white: 0.55) : Color(red: 142/255, green: 188/255, blue: 110/255))
        }
    }
    
    @ViewBuilder
    private func usageRow(usage: WindowUsage, fillColor: Color) -> some View {
        HStack(spacing: 8) {
            Text(usage.label)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 20, alignment: .leading)
            
            UsageProgressBar(progress: usage.progress, fillColor: fillColor, height: 7)
            
            Text(usage.percentageText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.65))
                .frame(width: 30, alignment: .trailing)
            
            Text(usage.formattedCountdown)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 62, alignment: .trailing)
                .lineLimit(1)
        }
    }
}

public struct WidgetView: View {
    @ObservedObject var tracker: UsageTracker
    @AppStorage("AIUsageWidget_PinOnTop") private var isPinnedOnTop: Bool = false
    @AppStorage("AIUsageWidget_EnableNotchIsland") private var isNotchEnabled: Bool = true
    
    public init(tracker: UsageTracker) {
        self.tracker = tracker
    }
    
    public var body: some View {
        WidgetContent(tracker: tracker, showRefresh: true)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(width: 350, height: 175)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.72))
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contextMenu {
                Button(action: {
                    WidgetWindowManager.shared.togglePinOnTop()
                }) {
                    Label(
                        isPinnedOnTop ? "✓ Pin on Top (Above Windows)" : "Pin on Top (Above Windows)",
                        systemImage: isPinnedOnTop ? "pin.fill" : "pin"
                    )
                }
                
                Button(action: {
                    WidgetWindowManager.shared.toggleNotchIsland()
                }) {
                    Label(
                        isNotchEnabled ? "✓ Notch Dynamic Island (Hover Top)" : "Notch Dynamic Island (Hover Top)",
                        systemImage: "menubar.dock.rectangle"
                    )
                }
                
                Button(action: {
                    WidgetWindowManager.shared.toggleLaunchAtLogin()
                }) {
                    let isLogin = SMAppService.mainApp.status == .enabled
                    Label(
                        isLogin ? "✓ Launch at Login" : "Launch at Login",
                        systemImage: "power"
                    )
                }
                
                Divider()
                
                Button(action: {
                    tracker.refresh()
                }) {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                }
                
                Button(action: {
                    WidgetWindowManager.shared.resetPosition()
                }) {
                    Label("Reset Position to Center", systemImage: "scope")
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit", systemImage: "xmark.circle")
                }
            }
    }
}
