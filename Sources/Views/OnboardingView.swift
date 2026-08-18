import SwiftUI
import ServiceManagement

public struct OnboardingView: View {
    @ObservedObject var tracker: UsageTracker
    public var onComplete: () -> Void
    
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
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ClaudeIconView(size: 18)
                    AntigravityIconView(size: 18)
                    Spacer()
                }
                
                Text("AI Usage Widget Setup")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Configure your monitoring preferences and permissions.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 1: Live Quota Permission
            VStack(alignment: .leading, spacing: 8) {
                Text("Live Quota Synchronization")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("To retrieve real-time Antigravity quotas, macOS requests permission to access the 'gemini' key in your Keychain. When prompted, enter your Mac password and click 'Always Allow'.")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(Color(white: 0.65))
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
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
                            }
                            Text(keychainAuthorized ? "Keychain Authorized" : "Authorize Keychain Access")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(keychainAuthorized ? Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.2) : Color.white.opacity(0.12))
                        .foregroundColor(keychainAuthorized ? Color(red: 48/255, green: 209/255, blue: 88/255) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(keychainAuthorized || isAuthorizingKeychain)
                    
                    Spacer()
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 2: Preferences
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferences")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Toggle(isOn: $enableNotch) {
                    Text("Display notch Dynamic Island (Hover top screen)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                }
                .toggleStyle(CheckboxToggleStyle())
                
                Toggle(isOn: $launchAtBoot) {
                    Text("Launch application at system startup")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                }
                .toggleStyle(CheckboxToggleStyle())
                
                Toggle(isOn: $stickToDesktop) {
                    Text("Stick to desktop layer (Behind application windows)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                }
                .toggleStyle(CheckboxToggleStyle())
            }
            
            Spacer(minLength: 4)
            
            // Finish Button
            Button(action: {
                savePreferencesAndComplete()
            }) {
                Text("Get Started")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 420, height: 460)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.85))
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

// Minimal native checkbox style for macOS SwiftUI
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(configuration.isOn ? Color.white : Color(white: 0.5))
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
