import Cocoa

class TutorialViewController: NSViewController {
    private var currentStep = 0
    private let tutorialSteps = [
        (title: "Welcome to Virtual Display", message: "This tutorial will show you how to use the app effectively."),
        (title: "Create a Virtual Display", message: "Adjust the capture overlay by dragging the corners or moving it with the handle. on the top left corner of the overlay window."),
        (title: "Start Capturing", message: "Click the start button to begin capturing your screen. The overlay will now show a click-through view of the capture area. and a new virtual display window will appear"),
        (title: "Share the virtual display", message: "You can now share the virtual display with others choosing the display window and clicking on the share button in your favorite messaging app."),
        (title: "Quick Controls", message: "CMD+S to start capturing. CMD+E to end capture and close the virtual display.")
    ]
    
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var messageLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 300
        return label
    }()
    
    private lazy var nextButton: NSButton = {
        let button = NSButton(title: "Next", target: self, action: #selector(nextButtonTapped))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        return button
    }()
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        view.addSubview(titleLabel)
        view.addSubview(messageLabel)
        view.addSubview(nextButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            nextButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        updateContent()
    }
    
    private func updateContent() {
        let step = tutorialSteps[currentStep]
        titleLabel.stringValue = step.title
        messageLabel.stringValue = step.message
        
        if currentStep == tutorialSteps.count - 1 {
            nextButton.title = "Finish"
        }
    }
    
    @objc private func nextButtonTapped() {
        if currentStep < tutorialSteps.count - 1 {
            currentStep += 1
            updateContent()
        } else {
            UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
            view.window?.close()
        }
    }
} 
