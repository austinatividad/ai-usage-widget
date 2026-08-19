import SwiftUI

public struct ProviderSettingsView: View {
    @ObservedObject var tracker: UsageTracker
    public var onClose: () -> Void
    
    @ObservedObject private var registry = ProviderRegistry.shared
    @AppStorage("AIUsageWidget_DisplayMode") private var displayModeRaw: String = WidgetDisplayMode.standard.rawValue
    
    @State private var isAuthorizingKeychain: Bool = false
    @State private var keychainAuthorized: Bool = false
    
    public init(tracker: UsageTracker, onClose: @escaping () -> Void) {
        self.tracker = tracker
        self.onClose = onClose
    }
    
    private var displayMode: WidgetDisplayMode {
        get { WidgetDisplayMode(rawValue: displayModeRaw) ?? .standard }
        set { displayModeRaw = newValue.rawValue }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                TachoLogoView(size: 34)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("tacho Settings")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Configure providers, display modes, and permissions.")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Color(white: 0.6))
                }
                
                Spacer()
                
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.6))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 1: Display Mode Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Widget Layout Style")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    ForEach(WidgetDisplayMode.allCases) { mode in
                        let isSelected = (displayMode == mode)
                        Button(action: {
                            displayModeRaw = mode.rawValue
                            WidgetWindowManager.shared.syncWindowDimensions()
                        }) {
                            VStack(spacing: 4) {
                                Text(mode.displayName)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .white : Color(white: 0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(displayMode.description)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(Color(white: 0.5))
                    .padding(.top, 2)
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 2: Providers List
            VStack(alignment: .leading, spacing: 8) {
                Text("Monitored Providers")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    ForEach(registry.allProviders, id: \.id) { provider in
                        let isEnabled = registry.isEnabled(id: provider.id)
                        let isInstalled = provider.isInstalledOnSystem
                        
                        HStack(spacing: 12) {
                            provider.makeIconView(size: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(provider.displayName)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(isInstalled ? "Detected" : "Not Found")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(isInstalled ? Color(red: 48/255, green: 209/255, blue: 88/255) : Color(white: 0.45))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(isInstalled ? Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.12) : Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                
                                Text(provider.quotaFormat == .percentUsed ? "Format: % Consumed" : "Format: % Available")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(Color(white: 0.5))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { isEnabled },
                                set: { newValue in
                                    registry.setEnabled(id: provider.id, enabled: newValue)
                                    tracker.updateEnabledProviders()
                                    WidgetWindowManager.shared.syncWindowDimensions()
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: Color.white))
                            .labelsHidden()
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 3: Live Synchronization
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Live Synchronization")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        isAuthorizingKeychain = true
                        Task {
                            let result = await QuotaService.fetchAntigravityQuota()
                            await MainActor.run {
                                isAuthorizingKeychain = false
                                if result != nil {
                                    keychainAuthorized = true
                                    tracker.refresh()
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            if isAuthorizingKeychain {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9))
                            }
                            Text(keychainAuthorized ? "Synchronized" : "Sync Now")
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 2)
            
            // Bottom Action
            HStack {
                Spacer()
                Button(action: {
                    onClose()
                }) {
                    Text("Done")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(width: 460, height: 530)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
