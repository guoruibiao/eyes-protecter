import AppKit
import QuartzCore

/// AppKit-level background for the overlay. Drawing the black base and the
/// optional photo here, instead of inside SwiftUI, guarantees that the very top
/// of the display (the menu bar / notch area) is covered too.
final class OverlayBackgroundView: NSView {
    private let imageLayer = CALayer()
    private let scrimLayer = CALayer()
    private(set) var image: NSImage?

    override var isOpaque: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.masksToBounds = true
        imageLayer.opacity = 0
        imageLayer.actions = ["contents": NSNull(), "opacity": NSNull(), "position": NSNull(), "bounds": NSNull()]
        layer?.addSublayer(imageLayer)

        // Slight darkening keeps white copy readable on bright photos.
        scrimLayer.backgroundColor = NSColor.black.withAlphaComponent(0.38).cgColor
        scrimLayer.opacity = 0
        scrimLayer.actions = ["opacity": NSNull(), "position": NSNull(), "bounds": NSNull()]
        layer?.addSublayer(scrimLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        scrimLayer.frame = bounds
        imageLayer.contentsScale = window?.backingScaleFactor ?? 2
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }

    func setImage(_ image: NSImage?) {
        self.image = image
        imageLayer.opacity = 0
        scrimLayer.opacity = 0

        guard let image else {
            imageLayer.contents = nil
            return
        }

        var proposedRect = NSRect(origin: .zero, size: image.size)
        imageLayer.contents = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
        imageLayer.contentsScale = window?.backingScaleFactor ?? 2
        needsLayout = true
    }

    /// Reveal the photo once the screen has finished fading to black.
    func revealImage(duration: TimeInterval) {
        guard image != nil else { return }
        let duration = max(0.2, duration)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.opacity = 1
        scrimLayer.opacity = 1
        CATransaction.commit()

        addOpacityAnimation(to: imageLayer, duration: duration)
        addOpacityAnimation(to: scrimLayer, duration: duration)
    }

    func showImageImmediately() {
        guard image != nil else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.opacity = 1
        scrimLayer.opacity = 1
        CATransaction.commit()
    }

    private func addOpacityAnimation(to layer: CALayer, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "reveal")
    }
}
