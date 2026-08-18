# Provider Extensibility Architecture, Codex Integration, and Provider Selection Specification

This document specifies the technical design for scaling the AI Usage Widget to support arbitrary AI providers, including the implementation requirements for Codex, a dedicated Provider Management Settings Window, and provider selection during initial onboarding.

---

## 1. Universal Provider Protocol Architecture

To eliminate provider-specific hardcoding, the widget architecture will transition to a protocol-driven provider registry.

```
+-----------------------------------------------------------------+
|                        ProviderRegistry                         |
|   - registeredProviders: [any AIProvider]                      |
|   - enabledProviderIds: Set<String> (UserDefaults)              |
|   - detectedProviders: [any AIProvider] (System Scan)           |
+--------------------------------+--------------------------------+
                                 |
         +-----------------------+-----------------------+
         |                       |                       |
+--------v---------+    +--------v---------+    +--------v---------+
|  ClaudeProvider  |    |   AGYProvider    |    |  CodexProvider   |
|   (AIProvider)   |    |   (AIProvider)   |    |   (AIProvider)   |
+------------------+    +------------------+    +------------------+
```

### 1.1 The `AIProvider` Protocol Contract

Every supported tool must implement the `AIProvider` protocol:

```swift
public protocol AIProvider: Sendable, Identifiable {
    /// Unique identifier (e.g., "claude", "antigravity", "codex")
    var id: String { get }
    
    /// Display name shown in header (e.g., "Codex CLI")
    var displayName: String { get }
    
    /// Official vector SVG icon view
    var icon: AnyView { get }
    
    /// Provider formatting style (.percentUsed or .percentRemaining)
    var quotaFormat: QuotaFormat { get }
    
    /// Primary accent color for progress bars
    var accentColor: Color { get }
    
    /// Filesystem paths monitored for real-time kernel events
    var monitoredPaths: [String] { get }
    
    /// Checks if the provider CLI installation exists on the local filesystem
    var isInstalledOnSystem: Bool { get }
    
    /// Method to fetch authenticated live quota from remote API
    func fetchLiveQuota() async -> LiveQuotaResult?
    
    /// Method to detect active CLI processes and turn states
    func detectSessionStatus() -> ActivityStatus
}
```

---

## 2. Provider Management Window (Accessed via Secondary Click)

A dedicated Provider Management Settings Window will allow users to configure and toggle installed AI providers at any time.

### 2.1 Access Points
1. **Secondary Click (Right-Click) Context Menu**: Adds menu item **"Manage Providers..."** with shortcut `⌘,`.
2. **Menu Bar Status Item**: Adds menu item **"Manage Providers..."**.

### 2.2 Window Specifications
- **Window Dimensions**: 480 pt width × 440 pt height.
- **Window Level**: Floating modal (`.floating`) with standard window close controls.
- **Visual Style**: Dark translucent glass (`.ultraThinMaterial`) matching system widget aesthetics.

### 2.3 Interface Layout & Controls
For each registered provider in `ProviderRegistry`:
1. **Header**: Provider icon, display name, and installation badge (`Installed` or `Not Detected`).
2. **Toggle Switch**: Enables or disables monitoring for that provider.
3. **Authorization Status**:
   - Displays whether Keychain credentials are valid.
   - Provides an **"Authorize Access"** button if permissions are missing.
4. **Live Preview**: Shows current quota percentage and session status for active providers.

```
+-------------------------------------------------------------+
| Manage AI Providers                                     [x] |
| Enable or disable monitoring for detected CLI tools.        |
+-------------------------------------------------------------+
| [🤖] Claude Code                     [Installed]  [ Toggle: ON ] |
|      Quota: % consumed · Status: 4 Idle                      |
|                                                             |
| [✨] Antigravity                     [Installed]  [ Toggle: ON ] |
|      Quota: % available · Status: Active                     |
|                                                             |
| [⚡️] Codex CLI                       [Installed]  [ Toggle: ON ] |
|      Quota: % consumed · Status: Idle                        |
+-------------------------------------------------------------+
|                                              [ Close Window ]|
+-------------------------------------------------------------+
```

---

## 3. Provider Selection in Initial Onboarding

The first-launch onboarding flow (`OnboardingView`) will include provider selection as the primary configuration step.

### 3.1 Onboarding Flow Steps
1. **Step 1: Provider Selection**
   - The application scans the filesystem for `~/.claude/`, `~/.gemini/`, and `~/.codex/`.
   - Automatically pre-selects all detected providers.
   - Allows users to check or uncheck individual providers.
2. **Step 2: Credential Authorization**
   - Requests Keychain authorization **only for enabled providers**.
   - Displays prominent instructions highlighting the **"Always Allow"** system prompt.
3. **Step 3: Display and Startup Preferences**
   - Configures Notch Dynamic Island, startup launch, and desktop window layer.
4. **Step 4: Completion**
   - Persists selections to `UserDefaults` and displays the configured widget.

---

## 4. Dynamic UI Scaling

The widget and notch dropdown interfaces adapt dynamically to the number of enabled providers:

1. **Height Calculation:**
   $$\text{Window Height} = 95\text{pt (Base Padding \& Controls)} + (40\text{pt} \times N_{\text{enabled providers}})$$
   - 1 Provider: 135 pt
   - 2 Providers: 175 pt
   - 3 Providers: 215 pt
   - 4 Providers: 255 pt

2. **Resource Optimization:**
   - Disabled providers attach zero `DispatchSource` filesystem watchers.
   - Disabled providers execute zero background network requests and zero process table scans.

---

## 5. Codex Integration Specification

### 5.1 Local Filesystem Layout
Codex stores session and authentication state in `~/.codex/`:

| Path | Purpose |
|---|---|
| `~/.codex/auth.json` | Stores API keys (`OPENAI_API_KEY`), tokens, and auth modes. |
| `~/.codex/process_manager/chat_processes.json` | JSON registry of active CLI processes and PID states. |
| `~/.codex/sessions/` | Directory containing active and past session logs. |
| `~/.codex/logs_2.sqlite` | SQLite database logging command execution steps. |
| Keychain Service: `"Codex Safe Storage"` | Stores encrypted tokens and keys in the macOS Keychain. |

---

### 5.2 Live Quota Synchronization
- **API Endpoint:** `https://api.openai.com/v1/usage` or OpenAI Dashboard Session API.
- **Header Limits:** Monitors `x-ratelimit-remaining-requests` and `x-ratelimit-reset-requests`.
- **Calculation:** Computes 5-hour rolling token windows and plan quotas.

---

### 5.3 Session & Process State Detection
1. **Active State (`● Active`):**
   - Validates live PID in `~/.codex/process_manager/chat_processes.json` using `kill(pid, 0)`.
   - Checks if `~/.codex/logs_2.sqlite-wal` was modified within 2.5 seconds.
2. **Approval State (`● Needs response`):**
   - Identifies pending permission prompts in active session files.
3. **Idle State (`● X Idle`):**
   - Process is alive in `chat_processes.json` with no active disk writes.
4. **Inactive State:**
   - No active processes in `chat_processes.json`.

---

## 6. Implementation Checklist

- [ ] **Phase 1: Universal Provider Architecture**
  - Create `AIProvider.swift` protocol and `ProviderRegistry.swift`.
  - Migrate `ClaudeProvider` and `AntigravityProvider` to conform to `AIProvider`.
- [ ] **Phase 2: Codex Provider Implementation**
  - Create `CodexProvider.swift`.
  - Add official Codex vector icon asset to `Sources/Resources/codex.svg`.
  - Implement credential extraction and process detection for Codex.
- [ ] **Phase 3: Dedicated Provider Management Window**
  - Create `ProviderSettingsView.swift`.
  - Wire secondary click menu item **"Manage Providers..."** to open settings window.
  - Implement dynamic window height adjustments on provider toggle.
- [ ] **Phase 4: Onboarding Integration**
  - Add Step 1 (Provider Discovery & Selection) to `OnboardingView.swift`.
  - Ensure permission requests only trigger for selected providers.
- [ ] **Phase 5: Verification & Packaging**
  - Verify multi-display notch expansion with 1, 2, and 3 enabled providers.
  - Update `README.md` and package `v0.0.2` application bundle.
