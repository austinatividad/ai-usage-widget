import AppKit
import SwiftUI
import ServiceManagement

@MainActor
public final class WidgetWindowManager: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static let shared = WidgetWindowManager()
    
    private var window: NSWindow?
    private var notchWindows: [NSWindow] = []
    private var statusItem: NSStatusItem?
    private let tracker = UsageTracker()
    
    private let windowPositionKey = "AIUsageWidget_WindowPosition"
    private let pinOnTopKey = "AIUsageWidget_PinOnTop"
    private let enableNotchKey = "AIUsageWidget_EnableNotchIsland"

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupWindow()
        setupNotchIslandWindows()
        
        // Listen to screen changes (plugging in / unplugging external monitors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Auto-register for login if not already set
        if UserDefaults.standard.object(forKey: "AIUsageWidget_AutoLoginRegistered") == nil {
            enableLaunchAtLogin(true)
            UserDefaults.standard.set(true, forKey: "AIUsageWidget_AutoLoginRegistered")
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent", accessibilityDescription: "AI Usage")
        }
        
        updateMenu()
    }
    
    public func updateMenu() {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "AI Usage Widget", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshAction), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Toggle Visibility", action: #selector(toggleVisibility), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Reset Position to Center", action: #selector(resetPosition), keyEquivalent: "0"))
        
        menu.addItem(NSMenuItem.separator())
        
        // Pin on top toggle
        let isPinned = UserDefaults.standard.bool(forKey: pinOnTopKey)
        let pinItem = NSMenuItem(title: "Pin on Top (Above Windows)", action: #selector(togglePinOnTopAction), keyEquivalent: "p")
        pinItem.state = isPinned ? .on : .off
        menu.addItem(pinItem)
        
        // Notch Island toggle
        let isNotchEnabled = UserDefaults.standard.object(forKey: enableNotchKey) as? Bool ?? true
        let notchItem = NSMenuItem(title: "Notch Dynamic Island (All Displays)", action: #selector(toggleNotchIslandAction), keyEquivalent: "n")
        notchItem.state = isNotchEnabled ? .on : .off
        menu.addItem(notchItem)
        
        // Launch at Login toggle
        let isLoginEnabled = SMAppService.mainApp.status == .enabled
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLoginAction), keyEquivalent: "l")
        loginItem.state = isLoginEnabled ? .on : .off
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }

    private func setupWindow() {
        let contentView = WidgetView(tracker: tracker)
        let hostingView = NSHostingView(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 350, height: 175),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        hostingView.wantsLayer = true
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        
        let isPinned = UserDefaults.standard.bool(forKey: pinOnTopKey)
        applyWindowLevel(to: window, isPinnedOnTop: isPinned)
        
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.delegate = self
        
        // Restore position
        if let savedPoint = UserDefaults.standard.string(forKey: windowPositionKey) {
            let point = NSPointFromString(savedPoint)
            window.setFrameOrigin(point)
        } else if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - 380
            let y = screenRect.maxY - 220
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func setupNotchIslandWindows() {
        // Clean up any existing notch windows
        for w in notchWindows {
            w.orderOut(nil)
        }
        notchWindows.removeAll()
        
        let isNotchEnabled = UserDefaults.standard.object(forKey: enableNotchKey) as? Bool ?? true
        guard isNotchEnabled else { return }
        
        // Deploy Notch Island HUD to ALL connected screens (Built-in + External Displays)
        for screen in NSScreen.screens {
            let screenRect = screen.frame
            
            let islandView = NotchIslandView(tracker: tracker)
            let hostingView = NSHostingView(rootView: islandView)
            hostingView.wantsLayer = true
            
            let notchWidth: CGFloat = 360
            let notchHeight: CGFloat = 210
            let x = screenRect.midX - (notchWidth / 2)
            let y = screenRect.maxY - notchHeight
            
            let nWindow = NSWindow(
                contentRect: NSRect(x: x, y: y, width: notchWidth, height: notchHeight),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            nWindow.contentView = hostingView
            nWindow.isOpaque = false
            nWindow.backgroundColor = .clear
            nWindow.hasShadow = false
            nWindow.isReleasedWhenClosed = false
            nWindow.level = .statusBar
            nWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            nWindow.ignoresMouseEvents = false
            
            nWindow.makeKeyAndOrderFront(nil)
            notchWindows.append(nWindow)
        }
    }

    @objc private func screenParametersChanged() {
        setupNotchIslandWindows()
    }

    private func applyWindowLevel(to window: NSWindow, isPinnedOnTop: Bool) {
        if isPinnedOnTop {
            window.level = .floating
        } else {
            let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
            window.level = NSWindow.Level(rawValue: desktopLevel)
        }
    }

    public func windowDidMove(_ notification: Notification) {
        guard let window = window else { return }
        let originString = NSStringFromPoint(window.frame.origin)
        UserDefaults.standard.set(originString, forKey: windowPositionKey)
    }

    public func togglePinOnTop() {
        guard let window = window else { return }
        let current = UserDefaults.standard.bool(forKey: pinOnTopKey)
        let newValue = !current
        UserDefaults.standard.set(newValue, forKey: pinOnTopKey)
        applyWindowLevel(to: window, isPinnedOnTop: newValue)
        updateMenu()
    }

    public func toggleNotchIsland() {
        let current = UserDefaults.standard.object(forKey: enableNotchKey) as? Bool ?? true
        let newValue = !current
        UserDefaults.standard.set(newValue, forKey: enableNotchKey)
        
        setupNotchIslandWindows()
        updateMenu()
    }

    public func toggleLaunchAtLogin() {
        let isCurrentlyEnabled = SMAppService.mainApp.status == .enabled
        enableLaunchAtLogin(!isCurrentlyEnabled)
        updateMenu()
    }

    @objc private func togglePinOnTopAction() {
        togglePinOnTop()
    }

    @objc private func toggleNotchIslandAction() {
        toggleNotchIsland()
    }

    @objc private func toggleLaunchAtLoginAction() {
        toggleLaunchAtLogin()
    }

    private func enableLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    @objc private func refreshAction() {
        tracker.refresh()
    }

    @objc private func toggleVisibility() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc public func resetPosition() {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let x = screenRect.midX - (window.frame.width / 2)
        let y = screenRect.midY - (window.frame.height / 2)
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
