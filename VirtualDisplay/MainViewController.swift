import Cocoa

class MainViewController: NSViewController, NSTabViewDelegate {
    
    // MARK: - UI Components
    
    private let tabView: NSTabView = {
        let tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder
        return tabView
    }()
    
    // About button
    private lazy var aboutButton: NSButton = {
        let button = NSButton(title: "About", target: self, action: #selector(showAboutView))
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }()
    
    // Tab views
    private let sharingTabView = NSView()
    private let appearanceTabView = NSView()
    
    // Sharing tab components
    private let sharingTitleLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "Screen Sharing")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .labelColor
        return label
    }()
    
    private let sharingStatusLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "Not sharing")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabelColor
        return label
    }()
    
    private lazy var startSharingButton: NSButton = {
        let button = NSButton(title: "Start Sharing", target: self, action: #selector(toggleSharing))
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }()
    
    private let sharingInstructionsLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "When sharing is active, a virtual display window will appear that shows the selected region of your screen. You can resize and move this window as needed.")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 400
        return label
    }()
    
    // Appearance tab components
    private let appearanceTitleLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "Appearance")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .labelColor
        return label
    }()
    
    // Border appearance components
    private let borderAppearanceTitleLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "Capture Overlay Border")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        return label
    }()
    
    // Thickness slider
    private let thicknessLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "Border Thickness:")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }()
    
    private lazy var thicknessSlider: NSSlider = {
        let slider = NSSlider(value: Double(borderThickness), minValue: 1, maxValue: 10, target: self, action: #selector(thicknessChanged(_:)))
        slider.tickMarkPosition = .below
        slider.numberOfTickMarks = 10
        slider.allowsTickMarkValuesOnly = true
        return slider
    }()
    
    private let thicknessValueLabel: NSTextField = {
        let label = NSTextField(labelWithString: "2 px")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        return label
    }()
    
    // Color picker
    private let colorLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "Border Color:")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }()
    
    private lazy var colorWell: NSColorWell = {
        let colorWell = NSColorWell()
        colorWell.color = borderColor
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        colorWell.isBordered = true
        return colorWell
    }()
    
    // Border properties
    private var borderThickness: CGFloat = 2.0 {
        didSet {
            thicknessValueLabel.stringValue = "\(Int(borderThickness)) px"
            updateBorderSettings()
            // Save preferences when changed
            UserPreferencesManager.shared.borderThickness = borderThickness
        }
    }
    private var borderColor: NSColor = NSColor.red.withAlphaComponent(0.7) {
        didSet {
            updateBorderSettings()
            // Save preferences when changed
            UserPreferencesManager.shared.borderColor = borderColor
        }
    }
    
    // Properties
    private var isSharing: Bool = false {
        didSet {
            updateSharingUI()
        }
    }
    
    // MARK: - Lifecycle
    
    private func loadPreferences() {
        // Load border appearance preferences
        borderThickness = UserPreferencesManager.shared.borderThickness
        borderColor = UserPreferencesManager.shared.borderColor
        
        // Update UI elements to reflect loaded preferences
        thicknessSlider.integerValue = Int(borderThickness)
        colorWell.color = borderColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadPreferences()
        setupUI()
        setupConstraints()
        updateSharingUI()
        updateBorderSettings() // Initialize border settings
        
        // Register for sharing status notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartSharing),
            name: Notification.Name("StartSharing"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEndSharing),
            name: Notification.Name("EndSharing"),
            object: nil
        )
        
        // Register for the new sharing status changed notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSharingStatusFromNotification),
            name: Notification.Name("SharingStatusChanged"),
            object: nil
        )
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Check current sharing status when view appears
        checkSharingStatus()
    }
    
    // Handle sharing notification from any source
    @objc private func handleStartSharing() {
        isSharing = true
    }
    
    @objc private func handleEndSharing() {
        isSharing = false
    }
    
    // This handles the new SharingStatusChanged notification
    @objc private func updateSharingStatusFromNotification() {
        // Get the current sharing status from AppDelegate
        checkSharingStatus()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Setup tab view
        setupTabView()
        
        // Setup tab contents
        setupSharingTab()
        setupAppearanceTab()
        
        // Add about button at bottom
        view.addSubview(aboutButton)
        
        // Set minimum size for the view to prevent shrinking
        if let window = view.window {
            window.minSize = NSSize(width: 480, height: 400)
        }
    }
    
    private func setupTabView() {
        view.addSubview(tabView)
        tabView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set delegate to handle tab switching
        tabView.delegate = self
        
        // Create tab view items with fixed size container views
        let sharingTab = NSTabViewItem(viewController: NSViewController())
        sharingTab.label = "Sharing"
        sharingTab.view = sharingTabView
        
        let appearanceTab = NSTabViewItem(viewController: NSViewController())
        appearanceTab.label = "Appearance"
        appearanceTab.view = appearanceTabView
        
        // Set fixed sizes for tab view containers to prevent resizing
        sharingTabView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sharingTabView.setContentHuggingPriority(.defaultLow, for: .vertical)
        appearanceTabView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        appearanceTabView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // Add minimum width constraints to tab views to avoid auto layout conflicts
        let minWidth: CGFloat = 100 // Minimum width to accommodate leading/trailing constraints
        
        let sharingMinWidth = NSLayoutConstraint(
            item: sharingTabView,
            attribute: .width,
            relatedBy: .greaterThanOrEqual,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1,
            constant: minWidth
        )
        sharingMinWidth.priority = .defaultHigh
        sharingTabView.addConstraint(sharingMinWidth)
        
        let appearanceMinWidth = NSLayoutConstraint(
            item: appearanceTabView,
            attribute: .width,
            relatedBy: .greaterThanOrEqual,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1,
            constant: minWidth
        )
        appearanceMinWidth.priority = .defaultHigh
        appearanceTabView.addConstraint(appearanceMinWidth)
        
        // Add tabs to tab view: Appearance first, then Sharing
        tabView.addTabViewItem(appearanceTab)
        tabView.addTabViewItem(sharingTab)
        
        // Set tab view properties
        tabView.font = .systemFont(ofSize: 13)
    }
    
    private func setupSharingTab() {
        sharingTabView.addSubview(sharingTitleLabel)
        // Hide sharing status label as requested
        // sharingTabView.addSubview(sharingStatusLabel)
        sharingTabView.addSubview(startSharingButton)
        sharingTabView.addSubview(sharingInstructionsLabel)
        
        sharingTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        // sharingStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        startSharingButton.translatesAutoresizingMaskIntoConstraints = false
        sharingInstructionsLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupAppearanceTab() {
        appearanceTabView.addSubview(appearanceTitleLabel)
        appearanceTabView.addSubview(borderAppearanceTitleLabel)
        appearanceTabView.addSubview(thicknessLabel)
        appearanceTabView.addSubview(thicknessSlider)
        appearanceTabView.addSubview(thicknessValueLabel)
        appearanceTabView.addSubview(colorLabel)
        appearanceTabView.addSubview(colorWell)
        
        appearanceTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        borderAppearanceTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        thicknessLabel.translatesAutoresizingMaskIntoConstraints = false
        thicknessSlider.translatesAutoresizingMaskIntoConstraints = false
        thicknessValueLabel.translatesAutoresizingMaskIntoConstraints = false
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        colorWell.translatesAutoresizingMaskIntoConstraints = false
    }
    
    // MARK: - Border Settings
    
    @objc private func thicknessChanged(_ sender: NSSlider) {
        borderThickness = CGFloat(sender.integerValue)
    }
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        borderColor = sender.color
    }
    
    private func updateBorderSettings() {
        // Create a dictionary with border settings
        let settings: [String: Any] = [
            "thickness": borderThickness,
            "color": borderColor
        ]
        
        // Post notification with border settings
        NotificationCenter.default.post(
            name: Notification.Name("BorderSettingsChanged"),
            object: nil,
            userInfo: settings
        )
    }
    
    private func addDivider(to parentView: NSView, belowView: NSView, spacing: CGFloat) {
        let divider = NSBox()
        divider.boxType = .separator
        parentView.addSubview(divider)
        
        // Ensure parent view has minimum width to avoid constraint conflicts
        let minWidth = NSLayoutConstraint(
            item: parentView,
            attribute: .width,
            relatedBy: .greaterThanOrEqual,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1,
            constant: 60 // Minimum width that can accommodate leading+trailing (20+20) constraints
        )
        minWidth.priority = .defaultHigh
        parentView.addConstraint(minWidth)
        
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),
            divider.topAnchor.constraint(equalTo: belowView.bottomAnchor, constant: spacing),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    // MARK: - Layout
    
    private func setupConstraints() {
        let margin: CGFloat = 20
        
        // Tab view constraints - ensure it has a fixed height
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            tabView.bottomAnchor.constraint(equalTo: aboutButton.topAnchor, constant: -margin),
            tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300) // Minimum height
        ])
        
        // About button constraints
        aboutButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            aboutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            aboutButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin)
        ])
        
        // Sharing tab constraints
        setupSharingTabConstraints()
        
        // Appearance tab constraints
        setupAppearanceTabConstraints()
    }
    
    private func setupSharingTabConstraints() {
        let margin: CGFloat = 20
        
        NSLayoutConstraint.activate([
            sharingTitleLabel.topAnchor.constraint(equalTo: sharingTabView.topAnchor, constant: margin),
            sharingTitleLabel.leadingAnchor.constraint(equalTo: sharingTabView.leadingAnchor, constant: margin),
            
            // Removed sharing status label constraints since it's hidden
            // sharingStatusLabel.topAnchor.constraint(equalTo: sharingTitleLabel.bottomAnchor, constant: 8),
            // sharingStatusLabel.leadingAnchor.constraint(equalTo: sharingTabView.leadingAnchor, constant: margin),
            
            startSharingButton.topAnchor.constraint(equalTo: sharingTitleLabel.bottomAnchor, constant: 8),
            startSharingButton.trailingAnchor.constraint(equalTo: sharingTabView.trailingAnchor, constant: -margin),
            
            // Updated instructions label to be positioned below the start button instead of status label
            sharingInstructionsLabel.topAnchor.constraint(equalTo: startSharingButton.bottomAnchor, constant: 20),
            sharingInstructionsLabel.leadingAnchor.constraint(equalTo: sharingTabView.leadingAnchor, constant: margin),
            sharingInstructionsLabel.trailingAnchor.constraint(equalTo: sharingTabView.trailingAnchor, constant: -margin)
        ])
    }
    
    private func setupAppearanceTabConstraints() {
        let margin: CGFloat = 20
        let componentSpacing: CGFloat = 12
        
        NSLayoutConstraint.activate([
            // Title
            appearanceTitleLabel.topAnchor.constraint(equalTo: appearanceTabView.topAnchor, constant: margin),
            appearanceTitleLabel.leadingAnchor.constraint(equalTo: appearanceTabView.leadingAnchor, constant: margin),
            
            // Border appearance title
            borderAppearanceTitleLabel.topAnchor.constraint(equalTo: appearanceTitleLabel.bottomAnchor, constant: margin),
            borderAppearanceTitleLabel.leadingAnchor.constraint(equalTo: appearanceTabView.leadingAnchor, constant: margin),
            
            // Thickness controls
            thicknessLabel.topAnchor.constraint(equalTo: borderAppearanceTitleLabel.bottomAnchor, constant: componentSpacing),
            thicknessLabel.leadingAnchor.constraint(equalTo: appearanceTabView.leadingAnchor, constant: margin),
            
            thicknessSlider.centerYAnchor.constraint(equalTo: thicknessLabel.centerYAnchor),
            thicknessSlider.leadingAnchor.constraint(equalTo: thicknessLabel.trailingAnchor, constant: 10),
            thicknessSlider.widthAnchor.constraint(equalToConstant: 150),
            
            thicknessValueLabel.centerYAnchor.constraint(equalTo: thicknessLabel.centerYAnchor),
            thicknessValueLabel.leadingAnchor.constraint(equalTo: thicknessSlider.trailingAnchor, constant: 10),
            
            // Color controls
            colorLabel.topAnchor.constraint(equalTo: thicknessLabel.bottomAnchor, constant: componentSpacing + 5),
            colorLabel.leadingAnchor.constraint(equalTo: appearanceTabView.leadingAnchor, constant: margin),
            
            colorWell.centerYAnchor.constraint(equalTo: colorLabel.centerYAnchor),
            colorWell.leadingAnchor.constraint(equalTo: colorLabel.trailingAnchor, constant: 10),
            colorWell.widthAnchor.constraint(equalToConstant: 44),
            colorWell.heightAnchor.constraint(equalToConstant: 23)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func toggleSharing() {
        isSharing.toggle()
        
        // Notify app delegate to handle actual sharing functionality
        let notificationName = isSharing ? Notification.Name("StartSharing") : Notification.Name("EndSharing")
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
    
    @objc private func showAboutView() {
        // Show the about view controller
        NotificationCenter.default.post(name: Notification.Name("ShowAboutView"), object: nil)
    }
    
    // MARK: - NSTabViewDelegate
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        // Prevent window resizing when switching tabs by maintaining the current window size
        if let window = view.window {
            let currentFrame = window.frame
            
            // Schedule a call to reset the window's frame in the next run loop
            // This prevents the window from automatically resizing due to content changes
            DispatchQueue.main.async {
                window.setFrame(currentFrame, display: true)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func updateSharingUI() {
        if isSharing {
            startSharingButton.title = "End Sharing"
            // Hide sharing status label as requested - no longer updating it
            // sharingStatusLabel.stringValue = "Currently sharing"
            // sharingStatusLabel.textColor = NSColor.systemGreen
        } else {
            startSharingButton.title = "Start Sharing"
            // Hide sharing status label as requested - no longer updating it
            // sharingStatusLabel.stringValue = "Not sharing"
            // sharingStatusLabel.textColor = NSColor.secondaryLabelColor
        }
    }
    
    private func checkSharingStatus() {
        // Get sharing status from AppDelegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            isSharing = appDelegate.isCurrentlySharing()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Set the window's minimum size when the view appears
        if let window = view.window {
            window.minSize = NSSize(width: 480, height: 400)
            
            // Make all tab content views the same size to prevent resizing
            let size = NSSize(width: window.frame.size.width - 40, height: 300)
            sharingTabView.setFrameSize(size)
            appearanceTabView.setFrameSize(size)
        }
    }
    
    deinit {
        // Remove notification observers when the view controller is deallocated
        NotificationCenter.default.removeObserver(self, name: Notification.Name("StartSharing"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("EndSharing"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("SharingStatusChanged"), object: nil)
    }
}
