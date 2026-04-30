import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set appearance to dark
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        // Give SwiftUI time to set up windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.backgroundColor = NSColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1.0)
                window.isOpaque = false
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
