import SwiftUI

/// Loads the MacBroom app icon
struct AppIconView: View {
    var size: CGFloat = 18
    
    var body: some View {
        if let nsImage = loadIcon() {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundStyle(MacBroomTheme.accent)
                .frame(width: size, height: size)
        }
    }
    
    private func loadIcon() -> NSImage? {
        let candidates: [Bundle] = [
            Bundle.main,
            Bundle(for: AppDelegate.self),
        ]
        
        let resourceNames = ["AppIcon", "broom_icon"]
        
        for bundle in candidates {
            for name in resourceNames {
                if let path = bundle.path(forResource: name, ofType: "png"),
                   let image = NSImage(contentsOfFile: path) {
                    return image
                }
            }
            
            // Try SPM resource bundle
            if let url = bundle.url(forResource: "MacBroom_MacBroom", withExtension: "bundle"),
               let resourceBundle = Bundle(url: url) {
                for name in resourceNames {
                    if let path = resourceBundle.path(forResource: name, ofType: "png"),
                       let image = NSImage(contentsOfFile: path) {
                        return image
                    }
                }
            }
        }
        
        // Fallback: hardcoded path
        if let image = NSImage(contentsOfFile: "/Users/hawazenmahmood/Documents/GitHub/MacBroom/Sources/MacBroom/Assets/AppIcon.png") {
            return image
        }
        
        return nil
    }
}
