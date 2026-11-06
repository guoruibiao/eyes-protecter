import AppKit
import SwiftUI

/// Shared state for every screen's overlay so the copy reveals in sync.
@MainActor
final class OverlayPresentation: ObservableObject {
    let message: String
    let hasImage: Bool
    @Published var isRevealed = false

    init(message: String, hasImage: Bool) {
        self.message = message
        self.hasImage = hasImage
    }
}

/// Creates one borderless panel per screen, fades them to black, and waits for
/// a click on the copy card before fading everything back out.
@MainActor
final class BreakOverlayController {
    private var panels: [OverlayPanel] = []
    private var presentation: OverlayPresentation?
    private var sourceImage: NSImage?
    private var onCardClick: (() -> Void)?
    private var isDismissing = false
    private var isInteractive = false
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rebuildForScreenChange()
            }
        }
    }

    func show(
        message: String,
        fadeIn: TimeInterval,
        image: NSImage?,
        onCardClick: @escaping () -> Void
    ) {
        guard panels.isEmpty else { return }
        isDismissing = false
        isInteractive = false
        sourceImage = image
        self.onCardClick = onCardClick

        let presentation = OverlayPresentation(message: message, hasImage: image != nil)
        self.presentation = presentation

        for screen in NSScreen.screens {
            let panel = makePanel(
                for: screen,
                presentation: presentation,
                image: image,
                onCardClick: onCardClick
            )
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        animateAlpha(to: 1, duration: fadeIn) { [weak self] in
            guard let self, !self.isDismissing else { return }
            self.presentation?.isRevealed = true
            self.isInteractive = true
            self.panels.forEach {
                $0.acceptsCardClicks = true
                $0.backgroundView?.revealImage(duration: 0.65)
            }
            // Keep the black screen truly empty while the mouse rests.
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    func dismiss(fadeOut: TimeInterval, completion: @escaping () -> Void) {
        guard !panels.isEmpty else {
            completion()
            return
        }
        guard !isDismissing else { return }

        isDismissing = true
        isInteractive = false
        panels.forEach { $0.acceptsCardClicks = false }

        animateAlpha(to: 0, duration: fadeOut) { [weak self] in
            guard let self else {
                completion()
                return
            }
            self.teardownPanels()
            completion()
        }
    }

    // MARK: - Panels

    private func makePanel(
        for screen: NSScreen,
        presentation: OverlayPresentation,
        image: NSImage?,
        onCardClick: @escaping () -> Void
    ) -> OverlayPanel {
        let frame = screen.frame
        let size = frame.size
        let cardSize = Self.cardSize(for: size)
        let cardRect = Self.cardRect(for: size, cardSize: cardSize)

        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.setFrame(frame, display: false)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.backgroundColor = .black
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        // Set the level last: some NSPanel properties can reset it.
        panel.level = .screenSaver
        panel.cardRect = cardRect
        panel.onCardClick = onCardClick

        let hosting = NSHostingView(
            rootView: OverlayCardView(presentation: presentation, cardSize: cardSize)
        )
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.wantsLayer = true

        let container = NSView(frame: CGRect(origin: .zero, size: size))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true

        let background = OverlayBackgroundView(frame: container.bounds)
        background.setImage(image)
        container.addSubview(background)

        container.addSubview(hosting)

        let cursorView = CursorRectView(frame: container.bounds, cardRect: cardRect)
        cursorView.autoresizingMask = [.width, .height]
        container.addSubview(cursorView)

        panel.contentView = container
        panel.backgroundView = background
        return panel
    }

    private func rebuildForScreenChange() {
        guard !panels.isEmpty, let oldPresentation = presentation, let onCardClick else { return }

        let interactive = isInteractive
        let image = sourceImage
        teardownPanels()

        let presentation = OverlayPresentation(message: oldPresentation.message, hasImage: image != nil)
        presentation.isRevealed = true
        self.presentation = presentation
        self.onCardClick = onCardClick
        self.sourceImage = image
        self.isInteractive = interactive

        for screen in NSScreen.screens {
            let panel = makePanel(
                for: screen,
                presentation: presentation,
                image: image,
                onCardClick: onCardClick
            )
            panel.alphaValue = 1
            panel.acceptsCardClicks = interactive
            if interactive {
                panel.backgroundView?.showImageImmediately()
            }
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    private func teardownPanels() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        presentation = nil
        onCardClick = nil
        isInteractive = false
        isDismissing = false
    }

    // MARK: - Helpers

    private func animateAlpha(to value: CGFloat, duration: TimeInterval, completion: @escaping () -> Void) {
        let duration = max(0, duration)
        guard duration > 0 else {
            panels.forEach { $0.alphaValue = value }
            completion()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panels.forEach { $0.animator().alphaValue = value }
        } completionHandler: {
            completion()
        }
    }

    static func cardSize(for screenSize: CGSize) -> CGSize {
        let horizontalInset = min(80, screenSize.width * 0.08)
        let width = max(300, min(580, screenSize.width - horizontalInset * 2))
        let height = max(240, min(320, screenSize.height - 160))
        return CGSize(width: width, height: height)
    }

    static func cardRect(for screenSize: CGSize, cardSize: CGSize) -> CGRect {
        CGRect(
            x: (screenSize.width - cardSize.width) / 2,
            y: (screenSize.height - cardSize.height) / 2,
            width: cardSize.width,
            height: cardSize.height
        )
    }
}

/// Borderless, non-activating window. Mouse handling happens at the window
/// level so the very first click on the card is never swallowed by AppKit's
/// "click to activate" behaviour.
final class OverlayPanel: NSPanel {
    var cardRect: CGRect = .zero
    var acceptsCardClicks = false
    var onCardClick: (() -> Void)?
    weak var backgroundView: OverlayBackgroundView?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if acceptsCardClicks, cardRect.contains(event.locationInWindow) {
                onCardClick?()
            }
            // Swallow the click either way; nothing behind the overlay should react.
            return
        case .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp, .scrollWheel:
            return
        default:
            super.sendEvent(event)
        }
    }
}

/// Purely decorative view that shows a pointing hand over the copy card.
final class CursorRectView: NSView {
    private let cardRect: CGRect

    init(frame: CGRect, cardRect: CGRect) {
        self.cardRect = cardRect
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func resetCursorRects() {
        addCursorRect(cardRect, cursor: .pointingHand)
    }
}
