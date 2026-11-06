import AppKit
import SwiftUI

enum DonationQRCode {
    static var url: URL? {
        if let bundled = Bundle.main.url(forResource: "DonationQRCode", withExtension: "jpg") {
            return bundled
        }

        let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/DonationQRCode.jpg")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    static let image: NSImage? = {
        guard let url = DonationQRCode.url, let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }()
}

struct DonationView: View {
    private let brandColor = Color(red: 0.12, green: 0.56, blue: 0.35)

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("请作者喝杯咖啡")
                    .font(.system(size: 20, weight: .semibold))
                Text("微信扫码打赏，感谢支持 Eyes Protecter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                if let image = DonationQRCode.image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: 460, maxHeight: 550)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1))
                        )
                        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48, weight: .light))
                        Text("收款码未找到")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 10) {
                if DonationQRCode.url != nil {
                    Button {
                        if let url = DonationQRCode.url {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("在预览中打开", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("关闭") {
                    NSApp.keyWindow?.performClose(nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColor)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 540, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(brandColor)
    }
}

@MainActor
final class DonationWindowController {
    static let shared = DonationWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let menuWindow = NSApp.keyWindow
        let hosting = NSHostingView(rootView: DonationView())
        hosting.frame = NSRect(x: 0, y: 0, width: 540, height: 720)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.title = "打赏作者 · 微信支付"
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let menuWindow, menuWindow !== window {
            menuWindow.orderOut(nil)
        }
        self.window = window
    }
}
