import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// Set to true only when user explicitly clicks Quit from menu bar
    private var shouldReallyQuit = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        registerLoginItem()
        
        // Replace Quit menu item after SwiftUI builds the menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.replaceQuitMenuItem()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.backgroundColor = NSColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1.0)
                window.isOpaque = false
            }
        }
    }
    
    // MARK: - Terminate Control
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check if this is a real quit (from menu bar quit button)
        if UserDefaults.standard.bool(forKey: "forceQuit") {
            UserDefaults.standard.set(false, forKey: "forceQuit")
            return .terminateNow
        }
        // ⌘Q or menu Quit → just hide
        hideApp()
        return .terminateCancel
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showApp()
        }
        return true
    }
    
    // MARK: - Menu Override
    
    private func replaceQuitMenuItem() {
        guard let mainMenu = NSApp.mainMenu else { return }
        for menuItem in mainMenu.items {
            guard let submenu = menuItem.submenu else { continue }
            for (index, item) in submenu.items.enumerated() {
                if item.title.contains("Quit") || item.title.contains("إنهاء") {
                    let newQuit = NSMenuItem(
                        title: item.title,
                        action: #selector(menuQuitAction(_:)),
                        keyEquivalent: "q"
                    )
                    newQuit.target = self
                    newQuit.keyEquivalentModifierMask = .command
                    submenu.removeItem(at: index)
                    submenu.insertItem(newQuit, at: index)
                    print("✅ Quit menu replaced")
                    return
                }
            }
        }
    }
    
    @objc private func menuQuitAction(_ sender: Any?) {
        hideApp()
    }
    
    // MARK: - Show/Hide
    
    func hideApp() {
        // Hide all regular windows (not panels/popovers)
        for window in NSApp.windows {
            if isRegularWindow(window) {
                window.orderOut(self)
            }
        }
        // Remove from Dock by setting activation policy to accessory
        NSApp.setActivationPolicy(.accessory)
    }
    
    func showApp() {
        // Show in Dock again
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if isRegularWindow(window) {
                window.makeKeyAndOrderFront(self)
            }
        }
    }
    
    /// True quit — only from menu bar Quit button
    func quitApp() {
        shouldReallyQuit = true
        NSApp.terminate(nil)
    }
    
    private func isRegularWindow(_ window: NSWindow) -> Bool {
        // Skip panels (menu bar popover), utility windows, and popups
        if window is NSPanel { return false }
        if window.styleMask.contains(.utilityWindow) { return false }
        if window.level == .popUpMenu || window.level == .statusBar { return false }
        return true
    }
    
    // MARK: - Login Item
    
    static func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    static func setLoginItemEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("❌ Login item error: \(error)")
            }
        }
    }
    
    private func registerLoginItem() {
        let defaults = UserDefaults.standard
        let key = "launchAtLogin"
        if defaults.object(forKey: key) == nil {
            defaults.set(true, forKey: key)
        }
        if defaults.bool(forKey: key) {
            Self.setLoginItemEnabled(true)
        }
    }
}
