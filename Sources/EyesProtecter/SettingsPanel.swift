import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 16) {
                statusCard
                intervalSection
                fadeInSection
                backgroundSection
                messageSection
                aboutSection
            }
            .padding(16)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 16)

            footer
        }
        .frame(width: 352)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            appIconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text("Eyes Protecter")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $model.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(model.isEnabled ? "暂停计时" : "开始计时")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var appIconBadge: some View {
        Group {
            if let image = Self.appIconImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
        .accessibilityLabel("Eyes Protecter")
    }

    private static let appIconImage: NSImage? = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        // Preview / swift run fallback when there is no app bundle.
        let preview = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("previews/icon.png")
        return NSImage(contentsOf: preview)
    }()

    // MARK: - Status

    private var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.statusTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(model.statusValue)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            Button {
                model.triggerBreak()
            } label: {
                Label("现在休息", systemImage: "moon.zzz.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(model.isBusy)
            .help("立即体验一次变暗效果")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.14))
        )
    }

    // MARK: - Settings

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("休息间隔")

            HStack {
                Text("\(model.intervalMinutes)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("分钟")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Stepper("", value: $model.intervalMinutes, in: 1...180)
                    .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )

            HStack(spacing: 6) {
                ForEach([15, 20, 30, 45, 60], id: \.self) { minutes in
                    Button {
                        model.intervalMinutes = minutes
                    } label: {
                        Text("\(minutes) 分")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .foregroundStyle(
                                model.intervalMinutes == minutes ? Color.accentColor : Color.secondary
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(
                                        model.intervalMinutes == minutes
                                            ? Color.accentColor.opacity(0.16)
                                            : Color.primary.opacity(0.045)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(
                                        model.intervalMinutes == minutes
                                            ? Color.accentColor.opacity(0.25)
                                            : Color.clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help("设为 \(minutes) 分钟")
                }
            }
        }
    }

    private var fadeInSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("进入休眠")

            HStack {
                Text("变暗时长")
                    .font(.system(size: 13))
                Spacer()
                Text("\(Int(model.fadeInSeconds)) 秒")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Stepper("", value: $model.fadeInSeconds, in: 1...20, step: 1)
                    .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )

            Text("屏幕会在这段时间里逐渐变黑，随后显示休眠画面。默认 10 秒。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("休眠画面")

            HStack(spacing: 10) {
                backgroundThumbnail

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.hasBackgroundImage ? "自定义图片" : "纯黑背景")
                        .font(.system(size: 12, weight: .medium))
                    Text(
                        model.hasBackgroundImage
                            ? (model.backgroundImageName ?? "已设置")
                            : "选择一张图片铺满整个屏幕"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                if model.hasBackgroundImage {
                    Button("更换") {
                        chooseBackgroundImage()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("换一张休眠背景图")

                    Button {
                        model.clearBackgroundImage()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("恢复纯黑背景")
                } else {
                    Button("选择图片…") {
                        chooseBackgroundImage()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )

            if let error = model.backgroundImageError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var backgroundThumbnail: some View {
        ZStack {
            Color.black

            if let image = model.backgroundImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .frame(width: 74, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14))
        )
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("休息文案")

            TextField("看向远处，眨眨眼", text: $model.message, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(2...4)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )

            Text("变暗后，点击这块文案才会逐渐恢复屏幕。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var aboutSection: some View {
        DisclosureGroup(isExpanded: $showAbout) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Eyes Protecter 会定时把屏幕逐渐变暗，提醒你离开屏幕、让眼睛休息。只有点击文案卡片后，屏幕才会恢复。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text("作者：泰戈尔")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Link(destination: githubURL) {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                            Text("github.com/guoruibiao")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.link)
                    .help("打开泰戈尔的 GitHub 主页")
                }

                Divider()
                    .opacity(0.5)

                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("系统要求")

                    VStack(spacing: 5) {
                        requirementRow("最低系统", "macOS 13 Ventura 或更高")
                        requirementRow("处理器", "Apple Silicon / Intel 64 位")
                        requirementRow("当前设备", "macOS \(currentOSVersion) · \(chipName)")
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.045))
                    )

                    Text("查看方式：苹果菜单 → 关于本机。App 无需屏幕录制或辅助功能权限。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                sectionTitle("关于")
                Text(appVersion)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Image(systemName: isCompatible ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(isCompatible ? Color.green : Color.red)
                    Text(isCompatible ? "可运行" : "不兼容")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                model.resetCountdown()
            } label: {
                Label("重新计时", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Pieces

    private var currentOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private var chipName: String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel 64 位"
        #else
        return "未知架构"
        #endif
    }

    private var isCompatible: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)
        )
    }

    private var githubURL: URL {
        URL(string: "https://github.com/guoruibiao")!
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v\(version ?? "2.0.0")"
    }

    private func requirementRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 11))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private func chooseBackgroundImage() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "选择休眠背景图片"
        panel.message = "图片会铺满每个屏幕；横向图片效果最好。"
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            model.setBackgroundImage(from: url)
        }
    }

}

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: model.menuBarSymbol)
            if model.showCountdown {
                Text(model.menuBarText)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("Eyes Protecter")
        .accessibilityValue(model.menuBarText)
    }
}
