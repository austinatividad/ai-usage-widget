import SwiftUI

public struct ProviderSettingsView: View {
    @ObservedObject var tracker: UsageTracker
    public var onClose: () -> Void
    
    @ObservedObject private var registry = ProviderRegistry.shared
    @State private var isAuthorizingKeychain: Bool = false
    @State private var keychainAuthorized: Bool = false
    
    public init(tracker: UsageTracker, onClose: @escaping () -> Void) {
        self.tracker = tracker
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage AI Providers")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Configure which CLI tools are monitored by the widget.")
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
            
            // Providers List
            VStack(spacing: 12) {
                ForEach(registry.allProviders, id: \.id) { provider in
                    let isEnabled = registry.isEnabled(id: provider.id)
                    let isInstalled = provider.isInstalledOnSystem
                    
                    HStack(spacing: 12) {
                        provider.makeIconView(size: 18)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(provider.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(isInstalled ? "Installed" : "Not Found")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(isInstalled ? Color(red: 48/255, green: 209/255, blue: 88/255) : Color(white: 0.45))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isInstalled ? Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.12) : Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            
                            Text(provider.quotaFormat == .percentUsed ? "Format: % Consumed" : "Format: % Available")
                                .font(.system(size: 10.5, weight: .regular))
                                .foregroundColor(Color(white: 0.55))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { isEnabled },
                            set: { newValue in
                                registry.setEnabled(id: provider.id, enabled: newValue)
                                tracker.updateEnabledProviders()
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: Color.white))
                        .labelsHidden()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Keychain Authorization Callout
            VStack(alignment: .leading, spacing: 8) {
                Text("Keychain Permissions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Select 'Always Allow' in the system prompt to enable background quota synchronization.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
                    .fixedSize(horizontal: false, vertical: true)
                
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
                    HStack(spacing: 6) {
                        if isAuthorizingKeychain {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                        }
                        Text(keychainAuthorized ? "Keychain Access Granted" : "Re-authorize Keychain Access")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
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
        .frame(width: 440, height: 470)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
