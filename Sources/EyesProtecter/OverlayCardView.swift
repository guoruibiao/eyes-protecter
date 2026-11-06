import SwiftUI

/// The copy card shown on top of the fully dimmed screen. The card's frame is
/// mirrored by `BreakOverlayController` so clicks can be matched at window level.
struct OverlayCardView: View {
    @ObservedObject var presentation: OverlayPresentation
    let cardSize: CGSize

    @State private var breathe = false

    var body: some View {
        ZStack {
            card
                .opacity(presentation.isRevealed ? 1 : 0)
                .scaleEffect(presentation.isRevealed ? 1 : 0.97)
                .animation(.easeOut(duration: 0.55), value: presentation.isRevealed)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private var card: some View {
        VStack(spacing: 24) {
            Image(systemName: "eye.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.35))

            Text(presentation.message)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .lineLimit(7)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: cardSize.width - 96)

            HStack(spacing: 8) {
                Image(systemName: "cursorarrow.click")
                Text("点击此区域，恢复屏幕")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(breathe ? 0.8 : 0.45))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.13)))
        }
        .padding(44)
        .frame(width: cardSize.width, height: cardSize.height)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: cardColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(presentation.hasImage ? 0.26 : 0.2), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.65), radius: 48, y: 18)
    }

    private var cardColors: [Color] {
        if presentation.hasImage {
            return [.black.opacity(0.66), .black.opacity(0.5)]
        }
        return [.white.opacity(0.065), .white.opacity(0.025)]
    }
}
