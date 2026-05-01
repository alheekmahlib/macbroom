import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var hasShownMainWindow = false
    
    static var shared: AppDelegate?
    
    /// Whether the app is running from /Applications (release build)
    static var isRunningFromApplications: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        // ===== Single Instance Enforcement =====
        // If another instance is already running, activate it and quit this one
        let bundleID = Bundle.main.bundleIdentifier ?? "com.macbroom.app"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let otherInstances = runningApps.filter { $0.processIdentifier != currentPID }
        
        if !otherInstances.isEmpty {
            // Activate the existing instance
            if let existing = otherInstances.first {
                existing.activate(options: [.activateIgnoringOtherApps])
                // Send a reopen event to show its window
                NSApp.activate(ignoringOtherApps: true)
            }
            // If we're not the /Applications version, just quit silently
            if !Self.isRunningFromApplications {
                NSApp.terminate(nil)
                return
            }
        }
        
        // Only register login item if running from /Applications
        // Debug builds should NEVER register as login items
        if Self.isRunningFromApplications {
            registerLoginItem()
        }
        
        // Catch ALL window openings and close duplicates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        // Handle Apple Events
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplication(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
        
        // Replace Quit menu item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.replaceQuitMenuItem()
        }
    }
    
    // MARK: - Single Window Enforcement
    
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if !isRegularWindow(window) { return }
        
        // Count how many regular visible windows we have
        let regularWindows = NSApp.windows.filter { isRegularWindow($0) && $0.isVisible }
        
        if regularWindows.count > 1 && hasShownMainWindow {
            // Close ALL windows except the last one opened, then show the original
            for w in regularWindows.dropLast() {
                w.close()
            }
            // The remaining window is the new one from WindowGroup — that's fine
        }
    }
    
    // MARK: - Apple Event Handler
    
    @objc private func handleOpenApplication(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // Instead of letting WindowGroup create a new window,
        // we show the existing one
        let regularWindows = NSApp.windows.filter { isRegularWindow($0) }
        
        if regularWindows.isEmpty {
            // No window at all — let WindowGroup handle it
            return
        }
        
        // We have a window — show it and prevent new one
        // The trick: set activation policy first, which signals macOS
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        for window in regularWindows {
            window.makeKeyAndOrderFront(self)
        }
        
        // Mark that we've shown the main window — next windowDidBecomeKey will close duplicates
        hasShownMainWindow = true
    }
    
    // MARK: - Terminate Control
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if UserDefaults.standard.bool(forKey: "forceQuit") {
            UserDefaults.standard.set(false, forKey: "forceQuit")
            return .terminateNow
        }
        hideApp()
        return .terminateCancel
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showApp()
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
        for window in NSApp.windows {
            if isRegularWindow(window) {
                window.orderOut(self)
            }
        }
        NSApp.setActivationPolicy(.accessory)
        hasShownMainWindow = true // Mark as shown so duplicates get closed on reopen
    }
    
    func showApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if isRegularWindow(window) {
                window.makeKeyAndOrderFront(self)
            }
        }
        hasShownMainWindow = true
    }
    
    private func isRegularWindow(_ window: NSWindow) -> Bool {
        if window is NSPanel { return false }
        if window.styleMask.contains(.utilityWindow) { return false }
        if window.level == .popUpMenu || window.level == .statusBar { return false }
        return true
    }
    
    // MARK: - Login Item
    
    static func isLoginItemEnabled() -> Bool {
        // Never report enabled for debug builds
        guard isRunningFromApplications else { return false }
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    static func setLoginItemEnabled(_ enabled: Bool) {
        // Never register/unregister login items for debug builds
        guard isRunningFromApplications else {
            print("⚠️ Skipping login item registration — not running from /Applications")
            return
        }
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
