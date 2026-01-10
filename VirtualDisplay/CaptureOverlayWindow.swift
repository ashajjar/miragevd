import Cocoa

class CaptureOverlayWindow: NSWindow, NSWindowDelegate {
    private var handleView: HandleView?
    private var startButton: NSButton?
    private var resizeHandleView: ResizeHandleView?
    weak var displayWindow: DisplayWindow?
    
    // Minimum dimensions for the capture overlay
    private let minimumWidth: CGFloat = 600.0
    private let minimumHeight: CGFloat = 600.0

    // Border properties
    private var borderThickness: CGFloat = 2.0
    private var borderColor: NSColor = NSColor.red.withAlphaComponent(0.7)

    // Keep overlay pinned while capturing
    // Use a high window level to keep overlay pinned while capturing
    private let capturePinnedLevel: NSWindow.Level = .mainMenu + 1

    private var spaceObserver: Any?
    
    // MARK: - Preferences Loading
    
    private func loadPreferences() {
        // Load border appearance preferences
        borderThickness = UserPreferencesManager.shared.borderThickness
        borderColor = UserPreferencesManager.shared.borderColor
    }

    init(frame: NSRect) {
        // Use the provided frame if valid; otherwise use saved preferences or center 600x600 on main screen
        var initialFrame = frame
        if initialFrame.isEmpty || initialFrame.width <= 0 || initialFrame.height <= 0 {
            // Use preferences manager to get initial frame
            initialFrame = UserPreferencesManager.shared.getInitialOverlayFrame()
        }

        // Enforce minimum dimensions
        if initialFrame.width < minimumWidth { initialFrame.size.width = minimumWidth }
        if initialFrame.height < minimumHeight { initialFrame.size.height = minimumHeight }

        super.init(contentRect: initialFrame,
                   styleMask: [.borderless, .resizable],
                   backing: .buffered,
                   defer: false)

        // Load preferences after super.init()
        loadPreferences()

        // Delegation & base window config
        self.delegate = self
        self.hidesOnDeactivate = true
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.level = .screenSaver // high by default
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true

        // Content view with a hand cursor everywhere (except handle)
        let contentView = CustomContentView(frame: initialFrame)
        contentView.parentWindow = self
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.borderWidth = borderThickness
        contentView.layer?.borderColor = borderColor.cgColor
        self.contentView = contentView

        // Notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBorderSettings(_:)),
            name: Notification.Name("BorderSettingsChanged"),
            object: nil
        )
        

        // Optional: keep re-pinning when Spaces change while capturing
        spaceObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: NSWorkspace.shared, queue: .main
        ) { [weak self] _ in
            guard let self = self, self.ignoresMouseEvents else { return } // using this flag as "capturing"
            self.orderFrontRegardless()
        }

        // Handle view (title/drag grip etc.)
        let handleSize = NSSize(width: 80, height: 30)
        let handleFrame = NSRect(
            x: (initialFrame.width - handleSize.width) / 2,
            y: initialFrame.height - handleSize.height - 10,
            width: handleSize.width, height: handleSize.height
        )
        handleView = HandleView(frame: handleFrame)
        contentView.addSubview(handleView!)

        // Start capture button
        let buttonSize = NSSize(width: 120, height: 30)
        let buttonFrame = NSRect(
            x: (initialFrame.width - buttonSize.width) / 2,
            y: 20, width: buttonSize.width, height: buttonSize.height
        )
        let btn = NSButton(frame: buttonFrame)
        btn.title = "Start Capture"
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.target = self
        btn.action = #selector(startCapture)
        btn.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor(red: 0.196, green: 0.843, blue: 0.294, alpha: 1.0).cgColor
        btn.layer?.cornerRadius = 6.0
        btn.contentTintColor = .white
        startButton = btn
        contentView.addSubview(btn)

        // Bottom-left resize handle (12x12), autoresizes with bottom-left corner
        let resizeHandleSize = NSSize(width: 12, height: 12)
        let resizeHandleFrame = NSRect(x: 0, y: 0, width: resizeHandleSize.width, height: resizeHandleSize.height)
        let r = ResizeHandleView(frame: resizeHandleFrame)
        r.autoresizingMask = [.maxXMargin, .maxYMargin]
        r.minimumSize = NSSize(width: minimumWidth, height: minimumHeight)
        r.corner = .bottomLeft
        contentView.addSubview(r)
        self.resizeHandleView = r
    }

    // Keep the overlay draggable with a hand cursor everywhere
    private class CustomContentView: NSView {
        weak var parentWindow: CaptureOverlayWindow?

        override func hitTest(_ point: NSPoint) -> NSView? {
            let hit = super.hitTest(point)
            if hit is ResizeHandleView || hit is NSButton || hit is HandleView {
                return hit
            }
            return self
        }

        // Drag the whole overlay
        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.set()
            parentWindow?.performDrag(with: event)
            NSCursor.openHand.set()
        }

        // Hand cursor across the entire overlay (except when a subview overrides)
        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .openHand)
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            window?.invalidateCursorRects(for: self)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.invalidateCursorRects(for: self)
        }
    }

    // MARK: - Always-on-top helpers during capture
    private func pinAlwaysOnTopForCapture() {
        hidesOnDeactivate = false
        collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary, .stationary])
        level = capturePinnedLevel
        orderFrontRegardless()
    }

    private func unpinAfterCapture() {
        level = .screenSaver
        orderFrontRegardless()
    }

    // MARK: - Show/Hide UI for capture
    private func revertCaptureChanges() {
        self.ignoresMouseEvents = false
        handleView?.isHidden = false
        startButton?.isHidden = false
        resizeHandleView?.isHidden = false
        
        hidesOnDeactivate = true
        unpinAfterCapture()
    }

    override func orderFront(_ sender: Any?) {
        revertCaptureChanges()
        super.orderFront(sender)
        orderFrontRegardless()
    }

    // MARK: - NSWindowDelegate (enforce minimum size and save preferences)
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        var newSize = frameSize
        if newSize.width < minimumWidth { newSize.width = minimumWidth }
        if newSize.height < minimumHeight { newSize.height = minimumHeight }
        return newSize
    }
    
    func windowDidMove(_ notification: Notification) {
        saveOverlayPreferences()
    }
    
    func windowDidResize(_ notification: Notification) {
        saveOverlayPreferences()
    }
    
    private func saveOverlayPreferences() {
        // Save the current frame and screen index
        let screenIndex = NSScreen.screens.firstIndex(of: self.screen ?? NSScreen.main!)
        UserPreferencesManager.shared.saveOverlayPreferences(
            frame: self.frame,
            screenIndex: screenIndex
        )
    }

    // MARK: - Start capture (pin overlay & keep visible)
    @objc func startCapture() {
        guard let screen = self.screen ?? NSScreen.main, let displayWindow = displayWindow else { return }

        print("🎯 CaptureOverlayWindow: Starting capture")
        print("🎯 CaptureOverlayWindow: Overlay frame: \(self.frame)")
        print("🎯 CaptureOverlayWindow: Overlay screen: \(screen.frame)")
        print("🎯 CaptureOverlayWindow: Display window screen: \(displayWindow.screen?.frame ?? .zero)")

        // Position display window on the same screen as the overlay to maintain proper scaling
        let margin = screen.frame.width * 0.05  // Smaller margin to fit better
        let displayFrame = NSRect(
            x: screen.frame.minX + margin, 
            y: self.frame.minY, 
            width: self.frame.width, 
            height: self.frame.height
        )
        displayWindow.setFrame(displayFrame, display: false)

        // Compute capture frame (exclude overlay border)
        let captureFrame = NSRect(
            x: self.frame.minX + borderThickness,
            y: self.frame.minY + borderThickness,
            width: self.frame.width - (2 * borderThickness),
            height: self.frame.height - (2 * borderThickness)
        )

        print("🎯 CaptureOverlayWindow: Capture frame: \(captureFrame)")
        print("🎯 CaptureOverlayWindow: Display frame: \(displayFrame)")

        // Make the overlay click-through but keep it pinned and visible everywhere
        self.ignoresMouseEvents = true
        handleView?.isHidden = true
        startButton?.isHidden = true
        resizeHandleView?.isHidden = true
        pinAlwaysOnTopForCapture()

        // Start the mirrored capture
        displayWindow.updateCaptureArea(frame: captureFrame, screen: screen)
        displayWindow.startCapture()

        NotificationCenter.default.post(name: Notification.Name("SharingStatusChanged"), object: nil)
    }

    // MARK: - Layout updates propagate to display window & capture area
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var adjustedFrame = frameRect
        if adjustedFrame.width < minimumWidth { adjustedFrame.size.width = minimumWidth }
        if adjustedFrame.height < minimumHeight { adjustedFrame.size.height = minimumHeight }

        super.setFrame(adjustedFrame, display: flag)

        // Handle position
        if let handleView = handleView {
            let handleFrame = NSRect(
                x: (adjustedFrame.width - handleView.frame.width) / 2,
                y: adjustedFrame.height - handleView.frame.height - 10,
                width: handleView.frame.width, height: handleView.frame.height
            )
            handleView.frame = handleFrame
        }

        // Button position
        if let startButton = startButton {
            let buttonFrame = NSRect(
                x: (adjustedFrame.width - startButton.frame.width) / 2,
                y: 20, width: startButton.frame.width, height: startButton.frame.height
            )
            startButton.frame = buttonFrame
        }

        // Bottom-left resize handle stays at (0,0) in content coords
        if let resizeHandleView = resizeHandleView {
            let handleSize = resizeHandleView.frame.size
            resizeHandleView.frame = NSRect(x: 0, y: 0, width: handleSize.width, height: handleSize.height)
        }
        
        // Keep the mirrored display window in sync (same screen as overlay)
        if let displayWindow = displayWindow, let screen = self.screen ?? NSScreen.main {
            let margin = screen.frame.width * 0.05
            let displayFrame = NSRect(
                x: screen.frame.minX + margin, 
                y: frameRect.minY, 
                width: frameRect.width, 
                height: frameRect.height
            )
            displayWindow.setFrame(displayFrame, display: true)
        }

        // Update capture area if currently capturing
        if let displayWindow = displayWindow, displayWindow.isCapturing, let screen = self.screen ?? NSScreen.main {
            let captureFrame = NSRect(
                x: frameRect.minX + borderThickness,
                y: frameRect.minY + borderThickness,
                width: frameRect.width - (2 * borderThickness),
                height: frameRect.height - (2 * borderThickness)
            )
            displayWindow.updateCaptureArea(frame: captureFrame, screen: screen)
        }
    }

    // MARK: - Border settings
    @objc private func updateBorderSettings(_ notification: Notification) {
        guard let settings = notification.userInfo else { return }

        if let thickness = settings["thickness"] as? CGFloat { borderThickness = thickness }
        if let color = settings["color"] as? NSColor { borderColor = color }

        if let contentView = contentView, contentView.wantsLayer {
            contentView.layer?.borderWidth = borderThickness
            contentView.layer?.borderColor = borderColor.cgColor
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let obs = spaceObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
