import SwiftUI
import ServiceManagement

public struct WidgetContent: View {
    @ObservedObject var tracker: UsageTracker
    public var mode: WidgetDisplayMode
    public var isHovered: Bool
    
    public init(tracker: UsageTracker, mode: WidgetDisplayMode = .standard, isHovered: Bool = false) {
        self.tracker = tracker
        self.mode = mode
        self.isHovered = isHovered
    }
    
    private var effectiveMode: WidgetDisplayMode {
        if mode == .hoverExpand {
            return isHovered ? .standard : .inline
        }
        return mode
    }
    
    public var body: some View {
        switch effectiveMode {
        case .standard:
            standardLayout
        case .inline, .hoverExpand:
            inlineLayout
        case .microStack:
            microStackLayout
        }
    }
    
    // MARK: - 1. Standard Layout (Full Detailed)
    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(tracker.activeProviders) { provider in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        providerIcon(id: provider.id, size: 14)
                        Text(provider.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        headerStatusBadge(usage: provider)
                    }
                    
                    standardUsageRow(usage: provider.usage5H, fillColor: providerFillColor(id: provider.id))
                    standardUsageRow(usage: provider.usage7D, fillColor: providerFillColor(id: provider.id))
                }
            }
        }
    }
    
    // MARK: - 2. Inline Layout (Concept A: Single-Row Compact)
    private var inlineLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tracker.activeProviders) { provider in
                HStack(spacing: 7) {
                    providerIcon(id: provider.id, size: 13)
                    
                    // 5H Micro Bar
                    HStack(spacing: 4) {
                        Text("5H")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                        
                        UsageProgressBar(progress: provider.usage5H.progress, fillColor: providerFillColor(id: provider.id), height: 5.5)
                            .frame(width: 44)
                        
                        Text(provider.usage5H.percentageText)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(white: 0.75))
                            .frame(width: 25, alignment: .trailing)
                    }
                    
                    // 7D Micro Bar
                    HStack(spacing: 4) {
                        Text("7D")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                        
                        UsageProgressBar(progress: provider.usage7D.progress, fillColor: providerFillColor(id: provider.id), height: 5.5)
                            .frame(width: 44)
                        
                        Text(provider.usage7D.percentageText)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(white: 0.75))
                            .frame(width: 25, alignment: .trailing)
                    }
                    
                    Spacer()
                    
                    miniStatusDot(status: provider.activityStatus)
                }
                .help("\(provider.name)\n5H: \(provider.usage5H.percentageText) (Refreshes in \(provider.usage5H.formattedCountdown))\n7D: \(provider.usage7D.percentageText) (Refreshes in \(provider.usage7D.formattedCountdown))")
            }
        }
    }
    
    // MARK: - 3. Micro Stack Layout (Concept B: Ultra-Narrow)
    private var microStackLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(tracker.activeProviders) { provider in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        providerIcon(id: provider.id, size: 12)
                        Text(provider.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        miniStatusDot(status: provider.activityStatus)
                    }
                    
                    // 5H Row
                    HStack(spacing: 5) {
                        Text("5H")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .frame(width: 16, alignment: .leading)
                        
                        UsageProgressBar(progress: provider.usage5H.progress, fillColor: providerFillColor(id: provider.id), height: 5)
                        
                        Text(provider.usage5H.percentageText)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.7))
                            .frame(width: 26, alignment: .trailing)
                    }
                    
                    // 7D Row
                    HStack(spacing: 5) {
                        Text("7D")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .frame(width: 16, alignment: .leading)
                        
                        UsageProgressBar(progress: provider.usage7D.progress, fillColor: providerFillColor(id: provider.id), height: 5)
                        
                        Text(provider.usage7D.percentageText)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.7))
                            .frame(width: 26, alignment: .trailing)
                    }
                }
                .help("\(provider.name)\n5H resets in \(provider.usage5H.formattedCountdown)\n7D resets in \(provider.usage7D.formattedCountdown)")
            }
        }
    }
    
    // MARK: - Components
    @ViewBuilder
    private func providerIcon(id: String, size: CGFloat) -> some View {
        switch id {
        case "claude":
            ClaudeIconView(size: size)
        case "antigravity":
            AntigravityIconView(size: size)
        case "codex":
            CodexIconView(size: size)
        default:
            Image(systemName: "cpu")
                .resizable()
                .frame(width: size, height: size)
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
    private func miniStatusDot(status: ActivityStatus) -> some View {
        switch status {
        case .needsResponse:
            Circle()
                .fill(Color(red: 255/255, green: 159/255, blue: 10/255))
                .frame(width: 5.5, height: 5.5)
        case .active:
            Circle()
                .fill(Color(red: 48/255, green: 209/255, blue: 88/255))
                .frame(width: 5.5, height: 5.5)
        case .idle:
            Circle()
                .fill(Color(white: 0.45))
                .frame(width: 4.5, height: 4.5)
        case .inactive:
            EmptyView()
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
    private func standardUsageRow(usage: WindowUsage, fillColor: Color) -> some View {
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
    @AppStorage("AIUsageWidget_DisplayMode") private var displayModeRaw: String = WidgetDisplayMode.standard.rawValue
    
    @State private var isHovered: Bool = false
    
    private var displayMode: WidgetDisplayMode {
        WidgetDisplayMode(rawValue: displayModeRaw) ?? .standard
    }
    
    public init(tracker: UsageTracker) {
        self.tracker = tracker
    }
    
    public var body: some View {
        let dimensions = tracker.widgetDimensions(for: displayMode, isHovered: isHovered)
        
        WidgetContent(tracker: tracker, mode: displayMode, isHovered: isHovered)
            .padding(.horizontal, displayMode == .microStack ? 14 : (displayMode == .inline ? 14 : 20))
            .padding(.vertical, displayMode == .inline ? 12 : 14)
            .frame(width: dimensions.width, height: dimensions.height)
            .background(
                RoundedRectangle(cornerRadius: displayMode == .inline ? 16 : 22, style: .continuous)
                    .fill(Color.black)
            )
            .clipShape(RoundedRectangle(cornerRadius: displayMode == .inline ? 16 : 22, style: .continuous))
            .onHover { hovering in
                if displayMode == .hoverExpand {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
                        isHovered = hovering
                    }
                    WidgetWindowManager.shared.syncWindowDimensions(isHovered: hovering)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: displayModeRaw)
            .animation(.easeInOut(duration: 0.22), value: tracker.activeProviders.count)
            .contextMenu {
                Menu("Display Mode") {
                    ForEach(WidgetDisplayMode.allCases) { mode in
                        Button(action: {
                            displayModeRaw = mode.rawValue
                            WidgetWindowManager.shared.syncWindowDimensions()
                        }) {
                            HStack {
                                if displayMode == mode {
                                    Text("✓ " + mode.displayName)
                                } else {
                                    Text(mode.displayName)
                                }
                            }
                        }
                    }
                }
                
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
