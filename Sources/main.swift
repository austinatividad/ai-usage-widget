import AppKit

let app = NSApplication.shared
let delegate = WidgetWindowManager.shared
app.delegate = delegate
app.setActivationPolicy(.accessory) // Accessory mode: runs cleanly in background with menu bar item and widget window
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
