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
        VStack(alignment: .leading, spacing: 18) {
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
                
                Text("Configure permissions and preferences for live monitoring.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Section 1: Live Quota Permission (High-Visibility Step Card)
            VStack(alignment: .leading, spacing: 10) {
                Text("1. Live Quota Authorization")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                // Prominent Instruction Callout Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("The application requests read access to the 'gemini' key in your macOS Keychain to synchronize rate limits.")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Color(white: 0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 6) {
                        Text("Action Required:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Select")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(white: 0.8))
                        
                        Text("Always Allow")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        
                        Text("in the system dialog.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(white: 0.8))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                
                // Authorization Action Button / Status
                if keychainAuthorized {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 48/255, green: 209/255, blue: 88/255))
                            .font(.system(size: 14))
                        Text("Keychain Access Authorized")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 48/255, green: 209/255, blue: 88/255))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
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
                        HStack(spacing: 8) {
                            if isAuthorizingKeychain {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 11))
                            }
                            Text(isAuthorizingKeychain ? "Waiting for Permission..." : "Authorize Keychain Access")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
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
            
            // Section 2: Preferences
            VStack(alignment: .leading, spacing: 10) {
                Text("2. Display and Startup Preferences")
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
                    .background(Color(white: 0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 440, height: 490)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.88))
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(configuration.isOn ? Color.white : Color(white: 0.5))
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
