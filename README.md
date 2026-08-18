# AI Usage Widget for macOS

AI Usage Widget is a native macOS desktop utility that monitors rate limits and session statuses for Claude Code and Antigravity.

---

## Overview

The application displays real-time quota consumption and active session states in two interface formats:
1. A desktop widget with adjustable window levels.
2. A Dynamic Island panel that expands from the display notch area on mouse hover.

---

## Features

### Display Notch Integration
- Expands automatically when the pointer enters the display notch area.
- Supports multi-display configurations and updates dynamically when displays connect or disconnect.
- Remains hidden when inactive.

### Real-Time Session Monitoring
- Identifies active command execution, approval prompts, and idle processes.
- Prioritizes actionable states when multiple terminal sessions operate concurrently.
- Uses POSIX system calls to verify process status without background polling overhead.

### Quota Tracking
- **Claude Code**: Tracks 5-hour rolling session limits and 7-day weekly quotas as percentage consumed.
- **Antigravity**: Tracks 5-hour rolling session limits and 7-day weekly quotas as percentage available.

### Window Management
- **Desktop Level**: Anchors below standard application windows directly above the desktop wallpaper.
- **Floating Level**: Pins above all active application windows.
- Persists window coordinates across system reboots and display reconfiguration.

### System Integration
- Provides a context menu on secondary click (right-click) for configuration.
- Includes a menu bar status item for quick actions.
- Supports automatic launch at system startup.

---

## Technical Specifications

| Parameter | Specification |
|---|---|
| Target Operating System | macOS 13.0 (Ventura) or later |
| Implementation Language | Swift 6.0 |
| UI Framework | SwiftUI / AppKit |
| CPU Utilization (Idle) | 0.0% |
| Memory Footprint | Approximately 20 MB |
| Concurrency Model | Swift 6 MainActor with structured concurrency |

---

## Architecture

| Function | Method | Description |
|---|---|---|
| Process Detection | `kill(pid, 0)` | Checks process table status for active Claude Code processes. |
| Lock Monitoring | `flock(fd, LOCK_EX \| LOCK_NB)` | Probes kernel file locks in the Antigravity presence directory. |
| Event Monitoring | `DispatchSourceFileSystemObject` | Receives kernel filesystem events with 80 ms event coalescing. |
| Window Leveling | `NSWindow.Level` | Sets window priority to `.desktopIconWindow + 1` or `.floating`. |

---

## Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later, or Swift 6.0 Command Line Tools

---

## Build and Installation

### Run Directly from Source
```bash
git clone https://github.com/austinatividad/ai-usage-widget.git
cd ai-usage-widget
swift run
```

### Build Application Bundle
Execute the packaging script to generate the release application bundle:
```bash
./scripts/bundle-app.sh
```

To open the application:
```bash
open AIUsageWidget.app
```

To install the application to the system Applications folder:
```bash
cp -r AIUsageWidget.app /Applications/
```

---

## Directory Structure

```
ai-usage-widget/
├── Package.swift                     # Swift Package Manager manifest
├── scripts/
│   └── bundle-app.sh                 # Application bundling script
├── Sources/
│   ├── main.swift                    # Application entry point
│   ├── Models/
│   │   ├── UsageData.swift           # Quota data models
│   │   ├── SessionDetector.swift     # Process and file lock detection
│   │   └── UsageTracker.swift        # Rolling quota calculations and file monitors
│   ├── Views/
│   │   ├── WidgetView.swift          # Main widget layout and context menu
│   │   ├── NotchIslandView.swift     # Display notch expansion view
│   │   ├── UsageProgressBar.swift    # Quota progress bar component
│   │   └── VectorIcons.swift         # Vector icon assets
│   ├── Window/
│   │   └── WidgetWindowManager.swift # Window controller and menu bar item
│   └── Resources/
│       ├── claude.svg                # Claude vector asset
│       └── antigravity.svg           # Antigravity vector asset
└── README.md
```

---

## License

This project is licensed under the MIT License.
