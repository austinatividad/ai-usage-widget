import SwiftUI
import ServiceManagement

public struct OnboardingView: View {
    @ObservedObject var tracker: UsageTracker
    public var onComplete: () -> Void
    
    @ObservedObject private var registry = ProviderRegistry.shared
    @State private var enableNotch: Bool = true
    @State private var launchAtBoot: Bool = true
    @State private var stickToDesktop: Bool = true
    @State private var isAuthorizingKeychain: Bool = false
    @State private var keychainAuthorized: Bool = false
    
    public init(tracker: UsageTracker, onComplete: @escaping () -> Void) {
        self.tracker = tracker
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 14) {
                TachoLogoView(size: 44)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("tacho Setup")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Select your tools and configure monitoring preferences.")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Color(white: 0.6))
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 1: Provider Discovery & Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Select Providers to Monitor")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                
                VStack(spacing: 6) {
                    ForEach(registry.allProviders, id: \.id) { provider in
                        let isEnabled = registry.isEnabled(id: provider.id)
                        let isInstalled = provider.isInstalledOnSystem
                        
                        Button(action: {
                            registry.setEnabled(id: provider.id, enabled: !isEnabled)
                            tracker.updateEnabledProviders()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(isEnabled ? .white : Color(white: 0.4))
                                
                                provider.makeIconView(size: 14)
                                
                                Text(provider.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(isInstalled ? "Detected" : "Not Found")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(isInstalled ? Color(red: 48/255, green: 209/255, blue: 88/255) : Color(white: 0.45))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 2: Live Quota Permission
            VStack(alignment: .leading, spacing: 8) {
                Text("2. Live Quota Authorization")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                
                // Prominent Instruction Callout Card
                VStack(alignment: .leading, spacing: 6) {
                    Text("The application requests read access to the 'gemini' key in your macOS Keychain to synchronize rate limits.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(white: 0.75))
                    
                    HStack(spacing: 5) {
                        Text("Action Required:")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Select")
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundColor(Color(white: 0.8))
                        
                        Text("Always Allow")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        
                        Text("in the system dialog.")
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundColor(Color(white: 0.8))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                if keychainAuthorized {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 48/255, green: 209/255, blue: 88/255))
                            .font(.system(size: 13))
                        Text("Keychain Access Authorized")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(Color(red: 48/255, green: 209/255, blue: 88/255))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
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
                            Text(isAuthorizingKeychain ? "Waiting for Permission..." : "Authorize Keychain Access")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthorizingKeychain)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 3: Preferences
            VStack(alignment: .leading, spacing: 8) {
                Text("3. Display Preferences")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                
                Toggle(isOn: $enableNotch) {
                    Text("Display notch Dynamic Island (Hover top screen)")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.white)
                }
                .toggleStyle(CheckboxToggleStyle())
                
                Toggle(isOn: $launchAtBoot) {
                    Text("Launch application at system startup")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.white)
                }
                .toggleStyle(CheckboxToggleStyle())
                
                Toggle(isOn: $stickToDesktop) {
                    Text("Stick to desktop layer (Behind application windows)")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.white)
                }
                .toggleStyle(CheckboxToggleStyle())
            }
            
            Spacer(minLength: 2)
            
            // Finish Button
            Button(action: {
                savePreferencesAndComplete()
            }) {
                Text("Get Started")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 440, height: 580)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.92))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            enableNotch = UserDefaults.standard.object(forKey: "AIUsageWidget_EnableNotchIsland") as? Bool ?? true
            stickToDesktop = !(UserDefaults.standard.bool(forKey: "AIUsageWidget_PinOnTop"))
            launchAtBoot = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func savePreferencesAndComplete() {
        UserDefaults.standard.set(enableNotch, forKey: "AIUsageWidget_EnableNotchIsland")
        UserDefaults.standard.set(!stickToDesktop, forKey: "AIUsageWidget_PinOnTop")
        UserDefaults.standard.set(true, forKey: "AIUsageWidget_HasCompletedOnboarding")
        
        if launchAtBoot {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
        
        onComplete()
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(configuration.isOn ? Color.white : Color(white: 0.5))
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
