import SwiftUI
import ServiceManagement

public struct WidgetContent: View {
    @ObservedObject var tracker: UsageTracker
    
    public init(tracker: UsageTracker) {
        self.tracker = tracker
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Dynamic Providers List
            ForEach(tracker.activeProviders) { provider in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        providerIcon(id: provider.id)
                        Text(provider.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        headerStatusBadge(usage: provider)
                    }
                    
                    // 5H Row
                    usageRow(usage: provider.usage5H, fillColor: providerFillColor(id: provider.id))
                    
                    // 7D Row
                    usageRow(usage: provider.usage7D, fillColor: providerFillColor(id: provider.id))
                }
            }
        }
    }
    
    @ViewBuilder
    private func providerIcon(id: String) -> some View {
        switch id {
        case "claude":
            ClaudeIconView(size: 14)
        case "antigravity":
            AntigravityIconView(size: 14)
        case "codex":
            CodexIconView(size: 14)
        default:
            Image(systemName: "cpu")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
        }
    }
    
    private func providerFillColor(id: String) -> Color {
        switch id {
        case "claude":
            return .white
        case "antigravity":
            return Color(red: 142/255, green: 188/255, blue: 110/255)
        case "codex":
            return Color(red: 16/255, green: 163/255, blue: 127/255)
        default:
            return .white
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
                .foregroundColor(providerSummaryColor(id: usage.id))
        }
    }
    
    private func providerSummaryColor(id: String) -> Color {
        switch id {
        case "claude":
            return Color(white: 0.55)
        case "antigravity":
            return Color(red: 142/255, green: 188/255, blue: 110/255)
        case "codex":
            return Color(red: 16/255, green: 163/255, blue: 127/255)
        default:
            return Color(white: 0.6)
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
        WidgetContent(tracker: tracker)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(width: 350, height: tracker.widgetHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.75))
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .animation(.easeInOut(duration: 0.25), value: tracker.widgetHeight)
            .contextMenu {
                Button(action: {
                    WidgetWindowManager.shared.openProviderSettings()
                }) {
                    Label("Manage Providers...", systemImage: "slider.horizontal.3")
                }
                
                Divider()
                
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
                    Label("Refresh Now (⌘R)", systemImage: "arrow.clockwise")
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
