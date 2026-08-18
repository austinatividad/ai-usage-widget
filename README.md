# AI Usage Widget (macOS)

<p align="center">
  <img src="Sources/Resources/claude.svg" width="48" height="48" alt="Claude" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="Sources/Resources/antigravity.svg" width="48" height="48" alt="Antigravity" />
</p>

<p align="center">
  <b>A minimalist, native macOS desktop widget & Dynamic Island HUD consolidating Claude Code and Antigravity rate limits and live agent states.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-black?style=flat-square&logo=apple" alt="macOS 13.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/Idle%20CPU-0.0%25-22c55e?style=flat-square" alt="0.0% CPU" />
  <img src="https://img.shields.io/badge/Memory-~20MB-3b82f6?style=flat-square" alt="~20MB RAM" />
</p>

---

## ✨ Features

### 1. 🏝️ Notch Dynamic Island (Multi-Display)
- **Top-Center Hover HUD:** Hover your mouse near the physical MacBook camera notch (or the top-center screen area on any connected external monitor).
- **Snappy 180ms Spring Animation:** Glides down smoothly with native iOS Dynamic Island physics (`.spring(response: 0.18, dampingFraction: 0.88)`).
- **Invisible Collapsed State:** 0 visual clutter on your display when idle.
- **Multi-Monitor Native:** Automatically deploys on all active screens with live hot-plug support.

### 2. ⚡️ Real-Time Live Session & Process Detection
- **`● Active` (Green):** Instant sub-second detection when an agent is actively coding, executing shell commands, or thinking.
- **`● Needs response` (Amber):** Surfaces immediately when an agent is waiting for user approval, tool permissions, or questions.
- **`● X Idle` (Muted):** Tracks multiple concurrent CLI sessions across terminal tabs.
- **Prioritized Urgency:** When multiple sessions are open, the widget highlights the most actionable tab (e.g. `Needs response (1 of 3)` > `2 Active` > `3 Idle`).

### 3. 📊 Native Provider Quota Semantics
- **Claude Code:** Tracks 5-Hour rolling window and 7-Day weekly quota in **`% used`** format with countdown timers (`0% used`, `24% used`).
- **Antigravity:** Tracks 5-Hour and 7-Day quota in **`% remaining`** format (`81% rem`, `97% rem`).

### 4. 📌 Desktop Sticking & Pin on Top
- **Stick to Desktop:** Sits on the desktop layer (`kCGDesktopIconWindowLevel + 1`) behind your active windows, directly on your wallpaper.
- **Pin on Top:** Toggle on to float above all active applications.
- **Persistent Position:** Drag anywhere; coordinates are automatically remembered across reboots and screen changes.

### 5. 🖱️ Right-Click Context Menu & Menu Bar Accessory
- Right-click anywhere directly on the widget or use the menu bar icon:
  - `Pin on Top (Above Windows)`
  - `Notch Dynamic Island (All Displays)`
  - `Launch at Login` (macOS `SMAppService`)
  - `Refresh Now (⌘R)`
  - `Reset Position to Center`
  - `Quit`

### 6. 🔋 Zero Battery Drain & Ultra-Lightweight
- **0.0% Idle CPU:** Event-driven kernel file watchers (`DispatchSource`) + coalescing = zero polling waste.
- **~20 MB RAM Footprint:** Native SwiftUI + AppKit vector caching.

---

## 🛠️ Architecture & Under the Hood

| Component | Technology | Mechanism |
|---|---|---|
| **Claude Detection** | POSIX `kill(pid, 0)` | Scans `~/.claude/sessions/*.json` and checks process liveness and `status` (`working`, `blocked`, `idle`). |
| **Antigravity Detection** | POSIX `flock` + Kernel Watchers | Probes active presence file locks on `~/.gemini/antigravity-cli/presence/*.lock` and tails SQLite WAL / transcript turn events. |
| **Event Watchers** | `DispatchSourceFileSystemObject` | Listens to kernel filesystem events on `DispatchQueue.main` with 80ms coalescing to prevent event storms. |
| **Window Layering** | AppKit `NSWindow.Level` | Configured with `.canJoinAllSpaces, .stationary, .ignoresCycle` for native wallpaper adhesion. |

---

## 🚀 Installation & Build

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15+ / Command Line Tools (`swift --version` >= 6.0)

### Quick Run
```bash
git clone https://github.com/austinatividad/ai-usage-widget.git
cd ai-usage-widget
swift run
```

### Build `.app` Application Bundle
```bash
./scripts/bundle-app.sh
open AIUsageWidget.app
```

To install to your Applications folder:
```bash
cp -r AIUsageWidget.app /Applications/
```

---

## 📁 Project Structure

```
ai-usage-widget/
├── Package.swift                     # Swift Package Manager manifest (macOS 13+)
├── scripts/
│   └── bundle-app.sh                 # Compiles release binary and creates .app bundle
├── Sources/
│   ├── main.swift                    # AppKit entry point (.accessory activation policy)
│   ├── Models/
│   │   ├── UsageData.swift           # Quota & session data models conforming to Sendable
│   │   ├── SessionDetector.swift     # POSIX process check & lock probe engine
│   │   └── UsageTracker.swift        # Rolling window tracker & DispatchSource listeners
│   ├── Views/
│   │   ├── WidgetView.swift          # Main 350x175 squircle view with context menu
│   │   ├── NotchIslandView.swift     # Dynamic Island notch dropdown with spring physics
│   │   ├── UsageProgressBar.swift    # Custom capsule progress bar with smooth animation
│   │   └── VectorIcons.swift         # Vector SVG assets with static in-memory caching
│   ├── Window/
│   │   └── WidgetWindowManager.swift # Multi-display window controller & menu bar manager
│   └── Resources/
│       ├── claude.svg                # Official Claude vector icon
│       └── antigravity.svg           # Official Antigravity vector icon
└── README.md
```

---

## 📄 License
MIT License. Created by [Austin Natividad](https://github.com/austinatividad).
