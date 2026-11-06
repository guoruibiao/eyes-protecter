import AppKit
import SwiftUI

@main
struct PreviewRenderer {
    @MainActor
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let outputDir = root.appendingPathComponent("previews", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let screenSize = CGSize(width: 1440, height: 900)
        let cardSize = BreakOverlayController.cardSize(for: screenSize)

        let plain = OverlayPresentation(message: "看向 6 米外，眨眨眼\n让眼睛休息一下", hasImage: false)
        plain.isRevealed = true
        let plainOverlay = ZStack {
            Color.black
            OverlayCardView(presentation: plain, cardSize: cardSize)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        render(plainOverlay, scale: 1, to: outputDir.appendingPathComponent("overlay.png"))

        if let sample = NSImage(contentsOf: root.appendingPathComponent("previews/sample-background.jpg")) {
            let withImage = OverlayPresentation(message: "看向 6 米外，眨眨眼\n让眼睛休息一下", hasImage: true)
            withImage.isRevealed = true
            let imageOverlay = ZStack {
                Color.black
                Image(nsImage: sample)
                    .resizable()
                    .scaledToFill()
                    .frame(width: screenSize.width, height: screenSize.height)
                    .clipped()
                Color.black.opacity(0.38)
                OverlayCardView(presentation: withImage, cardSize: cardSize)
            }
            .frame(width: screenSize.width, height: screenSize.height)
            render(imageOverlay, scale: 1, to: outputDir.appendingPathComponent("overlay-with-image.png"))
        }

    }

    @MainActor
    static func render<V: View>(_ view: V, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("render failed: \(url.lastPathComponent)\n", stderr)
            return
        }
        try? png.write(to: url)
        print("wrote \(url.path) (\(Int(image.size.width))x\(Int(image.size.height)))")
    }
}
