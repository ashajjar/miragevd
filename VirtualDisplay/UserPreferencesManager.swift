import Foundation
import AppKit

/// Manages persistent storage of user preferences for the Virtual Display app
class UserPreferencesManager {
    static let shared = UserPreferencesManager()
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let borderThickness = "borderThickness"
        static let borderColor = "borderColor"
        static let overlayFrame = "overlayFrame"
        static let overlayScreenIndex = "overlayScreenIndex"
    }
    
    // MARK: - Default Values
    private let defaultBorderThickness: CGFloat = 2.0
    private let defaultBorderColor = NSColor.red.withAlphaComponent(0.7)
    
    private init() {}
    
    // MARK: - Border Appearance Preferences
    
    /// Get the saved border thickness, or return default if not set
    var borderThickness: CGFloat {
        get {
            let saved = userDefaults.double(forKey: Keys.borderThickness)
            return saved > 0 ? CGFloat(saved) : defaultBorderThickness
        }
        set {
            userDefaults.set(Double(newValue), forKey: Keys.borderThickness)
        }
    }
    
    /// Get the saved border color, or return default if not set
    var borderColor: NSColor {
        get {
            guard let colorData = userDefaults.data(forKey: Keys.borderColor) else {
                return defaultBorderColor
            }
            
            do {
                if let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                    return color
                }
            } catch {
                print("Failed to decode border color: \(error)")
            }
            
            return defaultBorderColor
        }
        set {
            do {
                let colorData = try NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
                userDefaults.set(colorData, forKey: Keys.borderColor)
            } catch {
                print("Failed to encode border color: \(error)")
            }
        }
    }
    
    /// Save border appearance preferences
    func saveBorderPreferences(thickness: CGFloat, color: NSColor) {
        borderThickness = thickness
        borderColor = color
    }
    
    // MARK: - Overlay Position Preferences
    
    /// Get the saved overlay frame, or return nil if not set
    var overlayFrame: NSRect? {
        get {
            let frameData = userDefaults.data(forKey: Keys.overlayFrame)
            guard let data = frameData else { return nil }
            
            do {
                if let frame = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: data) {
                    return frame.rectValue
                }
            } catch {
                print("Failed to decode overlay frame: \(error)")
            }
            
            return nil
        }
        set {
            if let frame = newValue {
                do {
                    let frameValue = NSValue(rect: frame)
                    let data = try NSKeyedArchiver.archivedData(withRootObject: frameValue, requiringSecureCoding: false)
                    userDefaults.set(data, forKey: Keys.overlayFrame)
                } catch {
                    print("Failed to encode overlay frame: \(error)")
                }
            } else {
                userDefaults.removeObject(forKey: Keys.overlayFrame)
            }
        }
    }
    
    /// Get the saved screen index for the overlay, or return nil if not set
    var overlayScreenIndex: Int? {
        get {
            let index = userDefaults.integer(forKey: Keys.overlayScreenIndex)
            return index >= 0 ? index : nil
        }
        set {
            if let index = newValue {
                userDefaults.set(index, forKey: Keys.overlayScreenIndex)
            } else {
                userDefaults.removeObject(forKey: Keys.overlayScreenIndex)
            }
        }
    }
    
    /// Save overlay position and screen preferences
    func saveOverlayPreferences(frame: NSRect, screenIndex: Int?) {
        overlayFrame = frame
        overlayScreenIndex = screenIndex
    }
    
    /// Clear overlay position preferences (useful for reset)
    func clearOverlayPreferences() {
        overlayFrame = nil
        overlayScreenIndex = nil
    }
    
    // MARK: - Utility Methods
    
    /// Get the appropriate screen for the overlay based on saved preferences
    func getOverlayScreen() -> NSScreen? {
        if let screenIndex = overlayScreenIndex,
           screenIndex < NSScreen.screens.count {
            return NSScreen.screens[screenIndex]
        }
        return NSScreen.main
    }
    
    /// Get the initial frame for the overlay, considering saved preferences and screen bounds
    func getInitialOverlayFrame() -> NSRect {
        let screen = getOverlayScreen() ?? NSScreen.main!
        let minimumWidth: CGFloat = 600.0
        let minimumHeight: CGFloat = 600.0
        
        // If we have a saved frame, try to use it
        if let savedFrame = overlayFrame {
            // Validate that the saved frame is still valid (within screen bounds)
            let screenFrame = screen.frame
            if savedFrame.minX >= screenFrame.minX &&
               savedFrame.minY >= screenFrame.minY &&
               savedFrame.maxX <= screenFrame.maxX &&
               savedFrame.maxY <= screenFrame.maxY &&
               savedFrame.width >= minimumWidth &&
               savedFrame.height >= minimumHeight {
                return savedFrame
            }
        }
        
        // Fallback to centered frame
        let width: CGFloat = 600.0
        let height: CGFloat = 600.0
        return NSRect(
            x: (screen.frame.width - width) / 2,
            y: (screen.frame.height - height) / 2,
            width: width,
            height: height
        )
    }
    
    /// Reset all preferences to defaults
    func resetToDefaults() {
        userDefaults.removeObject(forKey: Keys.borderThickness)
        userDefaults.removeObject(forKey: Keys.borderColor)
        userDefaults.removeObject(forKey: Keys.overlayFrame)
        userDefaults.removeObject(forKey: Keys.overlayScreenIndex)
    }
}
