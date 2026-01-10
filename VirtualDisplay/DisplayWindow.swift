import Cocoa
import AVFoundation

public class DisplayWindow: NSWindow, NSWindowDelegate {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private var borderView: NSView?
    var overlayWindow: CaptureOverlayWindow?
    private var endButton: NSButton?
    private var hideButtonTimer: Timer?
    private var isButtonVisible = true
    private var isTrackingMouse = false
    var isCapturing = false
    private var overlayTextField: NSTextField?
    
    // Session timer properties
    private var sessionTimer: Timer?
    private var sessionStartTime: Date?
    private var sessionTimerLabel: NSTextField?
    
    // Constants for button animation
    private let buttonHiddenY: CGFloat = -40  // Hidden position below window
    private let buttonVisibleY: CGFloat = 20  // Visible position from bottom
    private let handleVisibleOffset: CGFloat = 10  // Offset from top when visible
    private let buttonAnimationDuration: TimeInterval = 0.3
    private let buttonAutoHideDelay: TimeInterval = 5.0
    
    init(frame: NSRect) {
        // Create window with standard macOS window styling including default border
        super.init(contentRect: frame,
                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                  backing: .buffered,
                  defer: false)
        
        // Set self as delegate
        self.delegate = self
        
        // Configure window properties
        self.title = "MirageVD"
        self.level = .normal
        self.isOpaque = true
        self.backgroundColor = NSColor.white
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .participatesInCycle]
        
        // Create and configure content view
        let contentView = NSView(frame: frame)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = contentView
        
        // Use default window border styling
        // Create a reference for managing border visibility state
        let borderView = NSView(frame: contentView.bounds)
        borderView.autoresizingMask = [.width, .height]
        self.borderView = borderView
        

        
        // Add end capture button
        let buttonSize = NSSize(width: 120, height: 30)
        let buttonFrame = NSRect(
            x: (frame.width - buttonSize.width) / 2,
            y: buttonVisibleY,  // Use the constant for initial position
            width: buttonSize.width,
            height: buttonSize.height
        )
        endButton = NSButton(frame: buttonFrame)
        endButton?.title = "End Capture"
        endButton?.bezelStyle = .regularSquare
        endButton?.isBordered = false
        endButton?.target = self
        endButton?.action = #selector(endCapture)
        endButton?.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        
        // Set FaceTime Red background color with clean appearance
        endButton?.wantsLayer = true
        endButton?.layer?.backgroundColor = NSColor(red: 0.996, green: 0.259, blue: 0.212, alpha: 1.0).cgColor
        endButton?.layer?.cornerRadius = 6.0
        endButton?.contentTintColor = NSColor.white
        
        endButton?.isHidden = true
        contentView.addSubview(endButton!)
        
        // Add text overlay
        let textRect = NSRect(
            x: 20, // Position in the top left corner with some padding
            y: frame.height - 50, // Position in the top left corner
            width: max(frame.width - 40, 100), // Ensure minimum width and allow space on the right
            height: 40
        )
        overlayTextField = NSTextField(frame: textRect)
        overlayTextField?.stringValue = "MirageVD"
        overlayTextField?.alignment = .left // Left-aligned text
        overlayTextField?.isEditable = false
        overlayTextField?.isBordered = false
        overlayTextField?.isSelectable = false
        overlayTextField?.drawsBackground = false
        overlayTextField?.textColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        overlayTextField?.font = NSFont.boldSystemFont(ofSize: 24) // Smaller font size
        // Fix autoresizing mask to avoid constraint conflicts with small parent view sizes
        overlayTextField?.autoresizingMask = [.width]
        overlayTextField?.alphaValue = 1.0 // Fully opaque
        
        // Add glowing effect
        overlayTextField?.wantsLayer = true
        overlayTextField?.layer?.shadowColor = NSColor.red.cgColor
        overlayTextField?.layer?.shadowOffset = CGSize(width: 0, height: 0)
        overlayTextField?.layer?.shadowOpacity = 0.8
        overlayTextField?.layer?.shadowRadius = 10.0
        contentView.addSubview(overlayTextField!)
        
        // Add session timer label in bottom right corner
        let timerRect = NSRect(
            x: frame.width - 120, // Position in the bottom right corner with padding
            y: 20, // Position from bottom
            width: 100, // Fixed width for timer display
            height: 30
        )
        sessionTimerLabel = NSTextField(frame: timerRect)
        sessionTimerLabel?.stringValue = "00:00:00"
        sessionTimerLabel?.alignment = .center
        sessionTimerLabel?.isEditable = false
        sessionTimerLabel?.isBordered = false
        sessionTimerLabel?.isSelectable = false
        sessionTimerLabel?.drawsBackground = false
        sessionTimerLabel?.textColor = NSColor.systemRed
        sessionTimerLabel?.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        sessionTimerLabel?.autoresizingMask = [.minXMargin, .minYMargin]
        sessionTimerLabel?.alphaValue = 0.8 // Semi-transparent
        sessionTimerLabel?.isHidden = true // Hidden initially
        
        // Add subtle background and shadow for better visibility
        sessionTimerLabel?.wantsLayer = true
        sessionTimerLabel?.layer?.cornerRadius = 6.0
        sessionTimerLabel?.layer?.shadowColor = NSColor.black.cgColor
        sessionTimerLabel?.layer?.shadowOffset = CGSize(width: 0, height: 1)
        sessionTimerLabel?.layer?.shadowOpacity = 0.5
        sessionTimerLabel?.layer?.shadowRadius = 2.0
        contentView.addSubview(sessionTimerLabel!)
        
        // Set up capture session but don't start it
        setupCaptureSession(frame: frame)
        
        // Ensure window is hidden initially
        self.orderOut(nil)
        
    }
    
    private func setupCaptureSession(frame: NSRect) {
        guard let screen = self.screen ?? NSScreen.main else { return }
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        // Create screen input
        guard let screenInput = createScreenInput(frame: frame, screen: screen) else {
            print("Failed to create screen input")
            return
        }
        
        // Add input to session
        if captureSession?.canAddInput(screenInput) == true {
            captureSession?.addInput(screenInput)
        }
        
        // Create preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = contentView?.bounds ?? frame
        previewLayer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        previewLayer?.videoGravity = .resize
        previewLayer?.backgroundColor = CGColor.clear
        previewLayer?.opacity = 0.0
        
        // Add preview layer to window
        if let previewLayer = previewLayer {
            contentView?.layer?.addSublayer(previewLayer)
            // Ensure border stays on top
            if let borderView = borderView {
                contentView?.addSubview(borderView)
            }
        }
        
        // Don't start capture session automatically
        // It will be started when capture begins
    } 
    
    private func createScreenInput(frame: NSRect, screen: NSScreen) -> AVCaptureScreenInput? {
        // Convert frame to screen coordinates
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        
        // Convert the frame to be relative to the target screen's coordinate system
        // The frame parameter is in global coordinates, we need to convert it to screen-relative coordinates
        let screenRelativeFrame = NSRect(
            x: frame.minX - screen.frame.minX,
            y: frame.minY - screen.frame.minY,
            width: frame.width,
            height: frame.height
        )
        
        // Create capture rectangle in screen coordinates
        let captureRect = CGRect(x: screenRelativeFrame.minX,
                               y: screenRelativeFrame.minY,
                               width: screenRelativeFrame.width,
                               height: screenRelativeFrame.height)
        
        print("🎯 DisplayWindow: Creating screen input for display ID: \(displayID)")
        print("🎯 DisplayWindow: Screen frame: \(screen.frame)")
        print("🎯 DisplayWindow: Original frame: \(frame)")
        print("🎯 DisplayWindow: Screen-relative frame: \(screenRelativeFrame)")
        print("🎯 DisplayWindow: Capture rect: \(captureRect)")
        
        // Create screen input
        guard let input = AVCaptureScreenInput(displayID: displayID) else { return nil }
        input.cropRect = captureRect
        input.minFrameDuration = CMTime(value: 1, timescale: 60) // 60 FPS
        input.capturesCursor = true
        input.capturesMouseClicks = false
        
        // Create and show overlay window if it doesn't exist
        if overlayWindow == nil {
            // Pass empty frame to trigger centering logic in CaptureOverlayWindow
            overlayWindow = CaptureOverlayWindow(frame: NSRect.zero)
            overlayWindow?.displayWindow = self
            overlayWindow?.orderFront(nil)
        }
        
        return input
    }
    
    deinit {
        captureSession?.stopRunning()
        overlayWindow?.close()
        stopSessionTimer()
    }
    
    func updateCaptureArea(frame: NSRect, screen: NSScreen? = nil) {
        guard let targetScreen = screen ?? self.screen ?? NSScreen.main,
              let captureSession = captureSession else { return }
        
        // Remove existing inputs
        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        // Create new screen input with updated frame
        if let newInput = createScreenInput(frame: frame, screen: targetScreen) {
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
            }
        }
        captureSession.commitConfiguration()
    }
    
    private func setupMouseTracking() {
        guard let contentView = contentView else { return }
        
        // Remove any existing tracking areas
        contentView.trackingAreas.forEach { contentView.removeTrackingArea($0) }
        
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],  // Removed .mouseMoved since we only care about enter/exit
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
        isTrackingMouse = true
    }
    
    private func animateControls(show: Bool) {
        guard let endButton = endButton else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = buttonAnimationDuration
            
            // Animate end button sliding down
            endButton.animator().frame.origin.y = show ? buttonVisibleY : buttonHiddenY
        }) {
            self.isButtonVisible = show
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        guard isCapturing else { return }
        animateControls(show: true)
    }
    
    public override func mouseExited(with event: NSEvent) {
        guard isCapturing else { return }
        animateControls(show: false)
    }
    
    // MARK: - Session Timer Methods
    
    private func startSessionTimer() {
        sessionStartTime = Date()
        
        // Timer is now hidden (no longer needed)
        sessionTimerLabel?.isHidden = true
        
        // Update timer every second (kept for potential future use)
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionTimer()
        }
    }
    
    private func updateSessionTimer() {
        guard let startTime = sessionStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        
        let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        sessionTimerLabel?.stringValue = timeString
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        sessionStartTime = nil
        sessionTimerLabel?.isHidden = true
        sessionTimerLabel?.stringValue = "00:00:00"
    }
    
    func startCapture() {
        print("startCapture")
        isCapturing = true
        self.orderFront(nil)
        endButton?.isHidden = false
        borderView?.isHidden = true // Hide any border state tracking
        
        // Set the aspect ratio based on the current window size to prevent distortion
        initialAspectRatio = frame.width / frame.height
        
        // Hide watermark (no longer needed)
        overlayTextField?.isHidden = true
        
        // Show preview layer
        previewLayer?.opacity = 1.0
        
        // Setup mouse tracking
        setupMouseTracking()
        
        // Start timer to hide controls
        hideButtonTimer?.invalidate()
        hideButtonTimer = Timer.scheduledTimer(withTimeInterval: buttonAutoHideDelay, repeats: false) { [weak self] _ in
            self?.animateControls(show: false)
        }
        
        // Start capture session if not already running
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
        
        // Start session timer (kept for potential future use)
        startSessionTimer()
    }
    
    @objc func endCapture() {
        print("endCapture")
        isCapturing = false
        
        // Update UI elements
        endButton?.isHidden = true
        borderView?.isHidden = false // Show any border state tracking
        overlayTextField?.isHidden = true // Hide the text overlay
        
        // Hide preview layer
        previewLayer?.opacity = 0.0
        
        // Stop capture session
        captureSession?.stopRunning()
        
        // Cleanup
        hideButtonTimer?.invalidate()
        hideButtonTimer = nil
        
        // Stop session timer
        stopSessionTimer()
        
        // Show overlay window
        overlayWindow?.orderFront(nil)
        
        // Hide the display window (instead of keeping it visible)
        self.orderOut(nil)
        
        // Post notification to update the UI status only (not trigger action again)
        NotificationCenter.default.post(name: Notification.Name("SharingStatusChanged"), object: nil)
    }
    
    public override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        

        
        // Update end button position while maintaining its current visibility state
        if let endButton = endButton {
            let currentY = isButtonVisible ? buttonVisibleY : buttonHiddenY
            let buttonFrame = NSRect(
                x: (frameRect.width - endButton.frame.width) / 2,
                y: currentY,
                width: endButton.frame.width,
                height: endButton.frame.height
            )
            endButton.frame = buttonFrame
        }
        
        // Update text overlay position
        if let textField = overlayTextField {
            let textFrame = NSRect(
                x: 20, // Keep in top left with padding
                y: frameRect.height - 80, // Position in the top left corner
                width: max(frameRect.width - 40, 100), // Ensure minimum width with padding
                height: textField.frame.height
            )
            textField.frame = textFrame
        }
        
        // Update session timer position
        if let timerLabel = sessionTimerLabel {
            let timerFrame = NSRect(
                x: frameRect.width - 120, // Position in the bottom right corner with padding
                y: 20, // Position from bottom
                width: 100, // Fixed width for timer display
                height: timerLabel.frame.height
            )
            timerLabel.frame = timerFrame
        }
        
        // Update tracking area when window size changes
        if isTrackingMouse {
            setupMouseTracking()
        }
    }
    
    private var bounds: NSRect {
        return contentView?.bounds ?? .zero
    }
    
    // Store initial aspect ratio
    private var initialAspectRatio: CGFloat = 1.0
    

    
    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Always enforce aspect ratio to prevent distortion
        // Calculate aspect ratio if not set
        if initialAspectRatio == 1.0 {
            initialAspectRatio = frame.width / frame.height
        }
        
        // Determine new size while maintaining aspect ratio
        let currentAspectRatio = frameSize.width / frameSize.height
        var newSize = frameSize
        
        if currentAspectRatio > initialAspectRatio {
            // Width is too large, adjust it based on height
            newSize.width = frameSize.height * initialAspectRatio
        } else if currentAspectRatio < initialAspectRatio {
            // Height is too large, adjust it based on width
            newSize.height = frameSize.width / initialAspectRatio
        }
        
        return newSize
    }
    
    // Handle window close button
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // If capturing, end capture first
        if isCapturing {
            endCapture()
        }
        
        // Hide window instead of closing it completely to preserve its state
        self.orderOut(nil)
        
        // Notify that window was closed
        NotificationCenter.default.post(name: Notification.Name("DisplayWindowClosed"), object: nil)
        
        // Return false to prevent actual window destruction
        return false
    }
} 
