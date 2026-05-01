import SwiftUI

@main
struct MacBroomApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private var menuBarImage: Image {
        let candidates: [Bundle] = [
            Bundle.main,
            Bundle(for: AppDelegate.self),
        ]
        
        for bundle in candidates {
            if let path = bundle.path(forResource: "MenuBarIcon", ofType: "png"),
               let nsImage = NSImage(contentsOfFile: path) {
                nsImage.isTemplate = true
                nsImage.size = NSSize(width: 18, height: 18)
                return Image(nsImage: nsImage)
            }
            if let url = bundle.url(forResource: "MacBroom_MacBroom", withExtension: "bundle"),
               let resourceBundle = Bundle(url: url),
               let path = resourceBundle.path(forResource: "MenuBarIcon", ofType: "png"),
               let nsImage = NSImage(contentsOfFile: path) {
                nsImage.isTemplate = true
                nsImage.size = NSSize(width: 18, height: 18)
                return Image(nsImage: nsImage)
            }
        }
        return Image(systemName: "sparkle")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .background(TitleBarAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appState)
        } label: {
            menuBarImage
        }
        .menuBarExtraStyle(.window)
    }
}

struct TitleBarAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.backgroundColor = NSColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1.0)
                window.isOpaque = false
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
