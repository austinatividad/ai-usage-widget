# Provider Extensibility Architecture and Codex Integration Specification

This document specifies the technical design for scaling the AI Usage Widget to support arbitrary AI providers, including the implementation requirements for Codex.

---

## 1. Universal Provider Protocol Architecture

To eliminate provider-specific hardcoding, the widget architecture will transition to a protocol-driven provider registry.

```
+-------------------------------------------------------------+
|                      ProviderRegistry                       |
|   - registeredProviders: [any AIProvider]                  |
|   - enabledProviderIds: Set<String> (UserDefaults)          |
+------------------------------+------------------------------+
                               |
         +---------------------+---------------------+
         |                     |                     |
+--------v-------+    +--------v-------+    +--------v-------+
| ClaudeProvider |    |  AGYProvider   |    | CodexProvider  |
|  (AIProvider)  |    |  (AIProvider)  |    |  (AIProvider)  |
+----------------+    +----------------+    +----------------+
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
    
    /// Method to fetch authenticated live quota from remote API
    func fetchLiveQuota() async -> LiveQuotaResult?
    
    /// Method to detect active CLI processes and turn states
    func detectSessionStatus() -> ActivityStatus
}
```

---

## 2. Dynamic UI Scaling

The widget and notch dropdown interfaces must adapt dynamically to the number of enabled providers:

1. **Height Computation:**
   $$\text{Window Height} = 95\text{pt (Base Padding \& Controls)} + (40\text{pt} \times N_{\text{enabled providers}})$$
   - 1 Provider: 135 pt
   - 2 Providers: 175 pt
   - 3 Providers: 215 pt

2. **Provider Selection in Settings:**
   - The context menu and onboarding screen will display toggle switches for each registered provider.
   - Disabled providers consume zero background resources, zero file descriptors, and zero CPU cycles.

---

## 3. Codex Integration Specification

### 3.1 Local Filesystem Layout
Codex stores session and authentication state in the user home directory at `~/.codex/`:

| Path | Purpose |
|---|---|
| `~/.codex/auth.json` | Stores API keys (`OPENAI_API_KEY`), tokens, and auth modes. |
| `~/.codex/process_manager/chat_processes.json` | JSON registry of active CLI processes and PID states. |
| `~/.codex/sessions/` | Directory containing active and past session logs. |
| `~/.codex/logs_2.sqlite` | SQLite database logging command execution steps. |
| Keychain Service: `"Codex Safe Storage"` | Stores encrypted tokens and keys in the macOS Keychain. |

---

### 3.2 Live Quota Synchronization

#### Method A: OpenAI API Subscription Limits
If Codex authenticates via OpenAI API Key or ChatGPT OAuth:
- **API Endpoint:** `https://api.openai.com/v1/usage` or OpenAI Dashboard Session API.
- **Header Rate Limits:** Inspects `x-ratelimit-remaining-requests`, `x-ratelimit-reset-requests`, and token usage buckets.

#### Method B: Rate Limit Calculation
- Calculates 5-hour rolling token windows and monthly/weekly plan quotas.
- Displays consumed percentage (`% used`) or remaining tokens based on account tier.

---

### 3.3 Session & Process State Detection

The Codex provider will detect runtime states as follows:

1. **Active State (`● Active`):**
   - Reads `~/.codex/process_manager/chat_processes.json`.
   - Validates live PID existence using `kill(pid, 0)`.
   - Verifies if SQLite WAL (`~/.codex/logs_2.sqlite-wal`) was modified within the last 2.5 seconds.

2. **Approval State (`● Needs response`):**
   - Identifies pending permission prompts or approval gates in active session files.

3. **Idle State (`● X Idle`):**
   - Process is active in `chat_processes.json` but no recent disk writes or tool executions are occurring.

4. **Inactive State:**
   - No active processes in `chat_processes.json` and process table is clear.

---

## 4. Implementation Checklist

- [ ] **Phase 1: Core Protocol Definition**
  - Create `AIProvider.swift` and `ProviderRegistry.swift`.
  - Refactor `ClaudeProvider` and `AntigravityProvider` to conform to `AIProvider`.
- [ ] **Phase 2: Codex Provider Implementation**
  - Implement `CodexProvider.swift`.
  - Add official Codex vector icon to `Sources/Resources/codex.svg`.
  - Implement credential extraction from `~/.codex/auth.json` and Keychain.
  - Implement process detection via `~/.codex/process_manager/chat_processes.json`.
- [ ] **Phase 3: Dynamic View Architecture**
  - Update `WidgetContent` and `NotchIslandView` to iterate over `tracker.enabledProviders`.
  - Implement dynamic window height calculation in `WidgetWindowManager`.
- [ ] **Phase 4: Settings & Onboarding Integration**
  - Add provider toggle checkboxes to `OnboardingView` and `WidgetView.contextMenu`.
