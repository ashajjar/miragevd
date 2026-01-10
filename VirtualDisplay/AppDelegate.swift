import Cocoa
import ScreenCaptureKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem?
    private var displayWindow: DisplayWindow?
    private var tutorialWindow: NSWindow?
    private var mainViewController: MainViewController?
    private var aboutViewController: ViewController?
    private var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show tutorial if it's the first launch
        if !UserDefaults.standard.bool(forKey: "hasSeenTutorial") {
            showTutorial()
        }
        
        // Set up view controllers
        setupViewControllers()
        
        // Position the main window in the bottom left corner of the screen
        if let screen = NSScreen.main, let window = mainWindow {
            // Calculate position for bottom left corner with a small margin
            let margin: CGFloat = 20
            let bottomLeftX = screen.frame.minX + margin
            let bottomLeftY = screen.frame.minY + margin
            
            window.setFrame(NSRect(
                x: bottomLeftX,
                y: bottomLeftY,
                width: window.frame.width,
                height: window.frame.height
            ), display: true)
        }
        
        // Set up a custom about menu handler to show the about view instead of creating a duplicate
        let mainMenu = NSApplication.shared.mainMenu
        if let appMenuItem = mainMenu?.item(at: 0),
           let appMenu = appMenuItem.submenu,
           let aboutMenuItem = appMenu.item(at: 0) {
            aboutMenuItem.action = #selector(showAbout)
        }
        
        // Register for notifications
        setupNotificationObservers()
        
        // Check screen recording permission
        checkScreenRecordingPermission()
        
        // Create status bar item
        setupStatusBarMenu()
        
        // Don't show the settings window on startup - user can access it via menu bar
    }
    
    private func setupViewControllers() {
        // Create main window if it doesn't exist
        if mainWindow == nil {
            mainWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            mainWindow?.title = "MirageVD"
            mainWindow?.isReleasedWhenClosed = false
            mainWindow?.center()
        }
        
        // Create main view controller if it doesn't exist
        if mainViewController == nil {
            mainViewController = MainViewController()
        }
        
        // Create about view controller if it doesn't exist
        if aboutViewController == nil {
            aboutViewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "AboutViewController") as? ViewController
        }
        
        // Set the initial view controller
        mainWindow?.contentViewController = mainViewController
        mainWindow?.title = "MirageVD Settings"
        // Don't show the window on startup - it will be shown when user clicks "Open Settings"
    }
    
    private func setupNotificationObservers() {
        // Listen for view switching notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showAbout),
            name: Notification.Name("ShowAboutView"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMainView),
            name: Notification.Name("ShowMainView"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startSharing),
            name: Notification.Name("StartSharing"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(endSharing),
            name: Notification.Name("EndSharing"),
            object: nil
        )
        
        // Listen for display window closed notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayWindowClosed),
            name: Notification.Name("DisplayWindowClosed"),
            object: nil
        )
    }
    
    private func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Set the image with appropriate size for the menu bar
            if let image = NSImage(named: "MenuBarIcon") {
                image.size = NSSize(width: 18, height: 18)  // Standard menu bar icon size
                button.image = image
            } else {
                // Fallback to text if image is not found
                button.title = "📺"
            }
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings(_:)), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Start Sharing", action: #selector(startSharing), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "End Sharing", action: #selector(endSharing), keyEquivalent: "e"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func openSettings(_ sender: Any?) {
        showMainView()
    }
    
    @objc private func copy(_ sender: Any?) {
        // Handle copy action - useful for copying text
        if let window = NSApp.keyWindow,
           let firstResponder = window.firstResponder,
           firstResponder.responds(to: #selector(NSText.copy(_:))) {
            firstResponder.perform(#selector(NSText.copy(_:)), with: sender)
        }
    }
    
    @objc private func paste(_ sender: Any?) {
        // Handle paste action - useful for pasting text
        if let window = NSApp.keyWindow,
           let firstResponder = window.firstResponder,
           firstResponder.responds(to: #selector(NSText.paste(_:))) {
            firstResponder.perform(#selector(NSText.paste(_:)), with: sender)
        }
    }
    
    private func showTutorial() {
        let tutorialVC = TutorialViewController()
        tutorialWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        tutorialWindow?.contentViewController = tutorialVC
        tutorialWindow?.title = "Welcome to Virtual Display"
        tutorialWindow?.center()
        tutorialWindow?.makeKeyAndOrderFront(nil)
        
        // Make the tutorial window stay on top
        tutorialWindow?.level = .floating
        
        // Center the tutorial window on screen
        if let screen = NSScreen.main {
            let centerX = screen.frame.midX - (tutorialWindow?.frame.width ?? 0) / 2
            let centerY = screen.frame.midY - (tutorialWindow?.frame.height ?? 0) / 2
            tutorialWindow?.setFrameOrigin(NSPoint(x: centerX, y: centerY))
        }
    }
    
    @objc private func createDisplay() {
        // Get the main screen's frame
        guard let screen = NSScreen.main else { return }
        
        // Calculate the same dimensions as used in CaptureOverlayWindow
        let margin = screen.frame.width * 0.1  // 10% margin from each side
        let width = screen.frame.width * 0.4   // 40% of screen width
        let height = screen.frame.height * 0.8  // 80% of screen height
        
        // Create window frame for top LEFT corner (under the menu bar)
        // This is the opposite side from where the CaptureOverlay window will be
        let frame = NSRect(
            x: margin, // Position on the left side with margin
            y: screen.frame.height - height - margin,
            width: width,
            height: height
        )
        
        // Create window but don't show it
        displayWindow = DisplayWindow(frame: frame)
        // Window will be shown when capture starts
    }
    
    private func checkScreenRecordingPermission() {
        Task {
            do {
                let content = try await SCShareableContent.current
                let authorized = content.displays.isEmpty == false
                
                if !authorized {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Screen Recording Permission Required"
                        alert.informativeText = "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Open System Settings")
                        alert.addButton(withTitle: "Cancel")
                        
                        if alert.runModal() == .alertFirstButtonReturn {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                } else {
                    print("Screen recording permission granted")
                    // Create display window when permission is granted
                    DispatchQueue.main.async {
                        self.createDisplay()
                    }
                }
            } catch {
                print("Error checking screen recording permission: \(error)")
            }
        }
    }
    
    @objc func startSharing(_ sender: Any?) {
        // Check if already capturing to prevent infinite loop
        if displayWindow?.isCapturing == true {
            return
        }
        
        if displayWindow == nil {
            createDisplay()
        }
        // Get the overlay window and trigger its start capture
        if let displayWindow = displayWindow,
           let overlayWindow = displayWindow.overlayWindow {
            overlayWindow.startCapture()
        }
    }
    
    @objc func endSharing(_ sender: Any?) {
        displayWindow?.endCapture()
    }
    
    @objc func handleDisplayWindowClosed(_ notification: Notification) {
        // Handle display window being closed by user
        // Update any UI or state that needs to be updated when the window is closed
        if displayWindow?.isCapturing == true {
            // If window was closed while capturing, ensure capture is ended properly
            displayWindow?.endCapture()
        }
    }
    
    // Menu item validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.title {
        case "Start Sharing":
            return displayWindow?.isCapturing == false
        case "End Sharing":
            return displayWindow?.isCapturing == true
        case "Copy":
            // Enable copy if there's a text field or text view that can be copied from
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder.responds(to: #selector(NSText.copy(_:))) {
                return true
            }
            return false
        case "Paste":
            // Enable paste if there's a text field or text view that can be pasted to
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder.responds(to: #selector(NSText.paste(_:))) {
                return true
            }
            return false
        default:
            return true
        }
    }
    
    // Public accessor for sharing status
    func isCurrentlySharing() -> Bool {
        return displayWindow?.isCapturing ?? false
    }
    
    @objc func showAbout(_ sender: Any? = nil) {
        guard let mainWindow = mainWindow, let aboutVC = aboutViewController else { return }
        
        // Update window title for About view
        mainWindow.title = "About MirageVD"
        
        // Save current frame to preserve position
        let currentFrame = mainWindow.frame
        
        // Set about view controller
        mainWindow.contentViewController = aboutVC
        
        // Ensure the about window has the same dimensions as the main window
        // (main window uses 480x400 as defined in setupViewControllers)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y,
            width: 480,
            height: 400
        )
        mainWindow.setFrame(newFrame, display: true, animate: true)
        
        // If window is minimized, restore it
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        
        // Make the window key and bring it to front
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showMainView(_ sender: Any? = nil) {
        guard let mainWindow = mainWindow, let mainVC = mainViewController else { return }
        
        // Update window title for Settings view
        mainWindow.title = "MirageVD Settings"
        
        // Save current frame to preserve position
        let currentFrame = mainWindow.frame
        
        // Set main view controller
        mainWindow.contentViewController = mainVC
        
        // Ensure the main window is always the same size (480x400)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y,
            width: 480,
            height: 400
        )
        mainWindow.setFrame(newFrame, display: true, animate: true)
        
        // If window is minimized, restore it
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        
        // Make the window key and bring it to front
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
}
