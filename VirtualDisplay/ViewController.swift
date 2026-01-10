//
//  ViewController.swift
//  VirtualDisplay
//
//  Created by Ahmad Hajjar on 19.02.25.
//

import Cocoa

class ViewController: NSViewController {
    private let iconImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSApp.applicationIconImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }()
    
    private let titleLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "MirageVD")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }()
    
    private let subtitleLabel: NSTextField = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let label = NSTextField(wrappingLabelWithString: "Version: \(version) \nBuild: \(build)")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        return label
    }()
    
    private let copyrightLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "Developed by Ahmad Hajjar")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        return label
    }()    
    private lazy var contactButton: NSButton = {
        let button = NSButton(title: "Contact Developer", target: self, action: #selector(contactDeveloper))
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }()
    
    private lazy var backButton: NSButton = {
        let button = NSButton(title: "Back", target: self, action: #selector(backToMain))
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Add all components
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(copyrightLabel)
        view.addSubview(contactButton)
        view.addSubview(backButton)
        
        // Configure auto layout
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        contactButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            iconImageView.widthAnchor.constraint(equalToConstant: 128),
            iconImageView.heightAnchor.constraint(equalToConstant: 128),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),

            copyrightLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copyrightLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            
            contactButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contactButton.topAnchor.constraint(equalTo: copyrightLabel.bottomAnchor, constant: 16),
            
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.topAnchor.constraint(equalTo: contactButton.bottomAnchor, constant: 16),
            backButton.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func backToMain() {
        NotificationCenter.default.post(name: Notification.Name("ShowMainView"), object: nil)
    }
    
    @objc private func contactDeveloper() {
        let email = "contact@ahmadhajjar.me"
        let subject = "MirageVD Support"
        let body = "Hello,\n\n"
        
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

