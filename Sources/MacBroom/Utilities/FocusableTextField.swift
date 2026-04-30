import SwiftUI

// MARK: - Focusable NSTextField wrapper
struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textField.textColor = NSColor.white
        textField.backgroundColor = NSColor.clear
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.alignment = .center
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // Focus immediately
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
            textField.window?.makeFirstResponder(textField)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        
        init(text: Binding<String>) {
            self.text = text
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text.wrappedValue = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle paste and other commands
            return false
        }
    }
}
