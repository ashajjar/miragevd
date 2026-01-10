import Cocoa

class HandleView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.6).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw drag handle icon (three horizontal lines)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        
        let centerX = bounds.midX
        let centerY = bounds.midY
        let lineLength: CGFloat = 20
        let lineSpacing: CGFloat = 4
        
        // Draw three horizontal lines to indicate drag handle
        for i in 0..<3 {
            let y = centerY + CGFloat(i - 1) * lineSpacing
            context.move(to: CGPoint(x: centerX - lineLength/2, y: y))
            context.addLine(to: CGPoint(x: centerX + lineLength/2, y: y))
            context.strokePath()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Let the parent view handle dragging - this view is just for visual indication
        super.mouseDown(with: event)
    }
} 