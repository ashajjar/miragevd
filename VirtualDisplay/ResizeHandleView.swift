import Cocoa

class ResizeHandleView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.7).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

 override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw resize handle icon (diagonal lines with dots)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        
        let margin: CGFloat = 4
        let lineSpacing: CGFloat = 4
        
        // Draw diagonal lines for resize handle
        for i in 0..<3 {
            let offset = CGFloat(i) * lineSpacing + margin
            context.move(to: CGPoint(x: offset, y: margin))
            context.addLine(to: CGPoint(x: margin, y: offset))
            context.strokePath()
        }
        
        // Add small dots at the end of each line to make it more obvious
        let dotRadius: CGFloat = 1.5
        for i in 0..<3 {
            let offset = CGFloat(i) * lineSpacing + margin
            // Dot at the end of horizontal part of line
            context.fillEllipse(in: CGRect(x: offset - dotRadius, y: margin - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            // Dot at the end of vertical part of line
            context.fillEllipse(in: CGRect(x: margin - dotRadius, y: offset - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        }
    }


    enum Corner { case bottomLeft, bottomRight, topLeft, topRight }
    var corner: Corner = .bottomLeft
    var minimumSize: NSSize = NSSize(width: 600, height: 600)

    override func resetCursorRects() {
        super.resetCursorRects()
        if #available(macOS 15.0, *) {
            let pos: NSCursor.FrameResizePosition = {
                switch corner {
                case .topLeft: return .topLeft
                case .topRight: return .topRight
                case .bottomLeft: return .bottomLeft
                case .bottomRight: return .bottomRight
                }
            }()
            addCursorRect(bounds, cursor: NSCursor.frameResize(position: pos, directions: .all))
        } else {
            // No public diagonal cursors pre-macOS 15; pick a close match.
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let win = window as? CaptureOverlayWindow else { return }

        let initialFrame = win.frame
        let screenForCalc = win.screen ?? NSScreen.main

        // Anchor the opposite corner (top-right in bottom-left resize)
        let anchoredTopRight = NSPoint(x: initialFrame.maxX, y: initialFrame.maxY)

        // Start cursor
        if #available(macOS 15.0, *) {
            NSCursor.frameResize(position: .bottomLeft, directions: .all).set()
        } else {
            NSCursor.resizeLeftRight.set()
        }

        // Use AppKit's native event-tracking loop (feels more "native" than monitors)
        win.trackEvents(matching: [.leftMouseDragged, .leftMouseUp],
                        timeout: 0.0,
                        mode: .eventTracking) { [weak self] e, stop in
            guard let self = self, let event = e else { stop.pointee = true; return }

            switch event.type {
            case .leftMouseDragged:
                // Compute in **screen coords** so math stays stable during live resize
                let pScreen = win.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin

                var newOrigin = NSPoint(x: min(pScreen.x, anchoredTopRight.x - self.minimumSize.width),
                                        y: min(pScreen.y, anchoredTopRight.y - self.minimumSize.height))
                var newSize = NSSize(width: anchoredTopRight.x - newOrigin.x,
                                     height: anchoredTopRight.y - newOrigin.y)

                // Clamp to visible screen so you don’t “lose” the window
                if let vis = screenForCalc?.visibleFrame {
                    newOrigin.x = max(vis.minX, newOrigin.x)
                    newOrigin.y = max(vis.minY, newOrigin.y)
                    newSize.width  = min(newSize.width,  vis.maxX - newOrigin.x)
                    newSize.height = min(newSize.height, vis.maxY - newOrigin.y)
                }

                // Enforce minimums again after clamping
                newSize.width  = max(newSize.width,  self.minimumSize.width)
                newSize.height = max(newSize.height, self.minimumSize.height)

                // Align to device pixels to avoid fuzzy borders on HiDPI
                let scale = win.backingScaleFactor
                newOrigin.x = (newOrigin.x * scale).rounded() / scale
                newOrigin.y = (newOrigin.y * scale).rounded() / scale
                newSize.width  = (newSize.width  * scale).rounded() / scale
                newSize.height = (newSize.height * scale).rounded() / scale

                let newFrame = NSRect(origin: newOrigin, size: newSize)
                // Let AppKit apply any window-level constraints
                let constrained = win.constrainFrameRect(newFrame, to: screenForCalc)
                win.setFrame(constrained, display: true)

            case .leftMouseUp:
                stop.pointee = true
                NSCursor.arrow.set()

            default:
                break
            }
        }
    }
}
