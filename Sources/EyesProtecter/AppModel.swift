import AppKit
import Combine
import Foundation

/// Owns the settings, the countdown and the break state machine.
///
/// Flow:
///   idle ──(timer reaches 0)──> breaking ──(card clicked)──> restoring ──> idle
///     ^                                                                     │
///     └──────────────────────── reset countdown ────────────────────────────┘
@MainActor
final class AppModel: ObservableObject {
    enum Phase {
        case idle
        case paused
        case breaking
        case restoring
    }

    private enum Key {
        static let intervalMinutes = "intervalMinutes"
        static let message = "message"
        static let fadeInSeconds = "fadeInSeconds"
        static let fadeOutSeconds = "fadeOutSeconds"
        static let isEnabled = "isEnabled"
        static let showCountdown = "showCountdown"
        static let backgroundImageName = "backgroundImageName"
    }

    static let defaultMessage = "看向 6 米外，眨眨眼\n让眼睛休息一下"
    static let defaultIntervalMinutes = 20

    private static let legacyDefaultMessage = "看向 6 米外，眨眨眼\n让眼睛休息 20 秒"
    private static let migrationMarker = "didMigrateFromMoveUrEyes"

    // MARK: - User editable settings

    @Published var intervalMinutes: Int {
        didSet {
            let clamped = min(max(intervalMinutes, 1), 180)
            if clamped != intervalMinutes {
                intervalMinutes = clamped
                return
            }
            defaults.set(intervalMinutes, forKey: Key.intervalMinutes)
            if phase == .idle {
                startCountdown()
            } else if phase == .paused {
                remaining = intervalSeconds
            }
        }
    }

    @Published var message: String {
        didSet {
            defaults.set(message, forKey: Key.message)
        }
    }

    @Published var fadeInSeconds: Double {
        didSet {
            let clamped = min(max(fadeInSeconds, 1), 20)
            if clamped != fadeInSeconds {
                fadeInSeconds = clamped
                return
            }
            defaults.set(fadeInSeconds, forKey: Key.fadeInSeconds)
        }
    }

    @Published var fadeOutSeconds: Double {
        didSet {
            let clamped = min(max(fadeOutSeconds, 0.5), 10)
            if clamped != fadeOutSeconds {
                fadeOutSeconds = clamped
                return
            }
            defaults.set(fadeOutSeconds, forKey: Key.fadeOutSeconds)
        }
    }

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Key.isEnabled)
            if isEnabled {
                if phase == .paused {
                    startCountdown()
                }
            } else {
                pauseCountdown()
            }
        }
    }

    @Published var showCountdown: Bool {
        didSet {
            defaults.set(showCountdown, forKey: Key.showCountdown)
        }
    }

    // MARK: - Runtime state

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remaining: TimeInterval = 0

    @Published private(set) var backgroundImage: NSImage?
    @Published private(set) var backgroundImageName: String?
    @Published var backgroundImageError: String?

    private let defaults: UserDefaults
    private let supportDirectory: URL
    private let overlay = BreakOverlayController()
    private var timer: Timer?
    private var nextBreakDate: Date?
    private var wakeObserver: NSObjectProtocol?

    // MARK: - Derived state

    var isBusy: Bool {
        phase == .breaking || phase == .restoring
    }

    var hasBackgroundImage: Bool {
        backgroundImage != nil
    }

    var intervalSeconds: TimeInterval {
        TimeInterval(intervalMinutes * 60)
    }

    var statusTitle: String {
        switch phase {
        case .idle: return "下次休息"
        case .paused: return "已暂停"
        case .breaking: return "正在休息"
        case .restoring: return "正在恢复"
        }
    }

    var statusValue: String {
        switch phase {
        case .idle, .paused:
            return Self.timeString(from: remaining)
        case .breaking:
            return "休息中"
        case .restoring:
            return "马上回来"
        }
    }

    var menuBarText: String {
        switch phase {
        case .idle: return Self.timeString(from: remaining)
        case .paused: return "暂停"
        case .breaking: return "休息"
        case .restoring: return "恢复"
        }
    }

    var menuBarSymbol: String {
        switch phase {
        case .idle: return "eye"
        case .paused: return "pause.circle"
        case .breaking: return "eye.slash"
        case .restoring: return "sun.max"
        }
    }

    var subtitle: String {
        if isEnabled {
            return "定时变暗屏幕，提醒你让眼睛休息"
        }
        return "计时已暂停"
    }

    // MARK: - Lifecycle

    init(defaults: UserDefaults = .standard, supportDirectory: URL? = nil) {
        let resolvedSupportDirectory = supportDirectory ?? Self.defaultSupportDirectory
        self.defaults = defaults
        self.supportDirectory = resolvedSupportDirectory

        if defaults === UserDefaults.standard {
            Self.migrateLegacyDataIfNeeded(
                defaults: defaults,
                supportDirectory: resolvedSupportDirectory
            )
        }

        let storedInterval = defaults.object(forKey: Key.intervalMinutes) as? Int
        let storedFadeIn = defaults.object(forKey: Key.fadeInSeconds) as? Double
        let storedFadeOut = defaults.object(forKey: Key.fadeOutSeconds) as? Double
        let storedEnabled = defaults.object(forKey: Key.isEnabled) as? Bool
        let storedShowCountdown = defaults.object(forKey: Key.showCountdown) as? Bool

        intervalMinutes = min(max(storedInterval ?? Self.defaultIntervalMinutes, 1), 180)
        message = defaults.string(forKey: Key.message) ?? Self.defaultMessage
        fadeInSeconds = min(max(storedFadeIn ?? 10, 1), 20)
        fadeOutSeconds = min(max(storedFadeOut ?? 3, 0.5), 10)
        isEnabled = storedEnabled ?? true
        showCountdown = storedShowCountdown ?? true
        remaining = intervalSeconds

        if let savedName = defaults.string(forKey: Key.backgroundImageName) {
            if let image = NSImage(contentsOf: backgroundImageURL) {
                backgroundImage = image
                backgroundImageName = savedName
            } else {
                defaults.removeObject(forKey: Key.backgroundImageName)
            }
        }

        if isEnabled {
            startCountdown()
        } else {
            phase = .paused
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .idle else { return }
                // Do not fire a break immediately after waking from sleep.
                self.startCountdown()
            }
        }
    }

    // MARK: - Actions

    /// Show the dimming overlay right now (also used as a preview).
    func triggerBreak() {
        guard phase != .breaking, phase != .restoring else { return }

        stopTimer()
        phase = .breaking
        remaining = 0

        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        overlay.show(
            message: text.isEmpty ? "让眼睛休息一下" : text,
            fadeIn: fadeInSeconds,
            image: backgroundImage
        ) { [weak self] in
            self?.beginRestore()
        }
    }

    /// Restart the countdown from the configured interval.
    func resetCountdown() {
        guard phase != .breaking, phase != .restoring else { return }
        if isEnabled {
            startCountdown()
        } else {
            stopTimer()
            phase = .paused
            remaining = intervalSeconds
        }
    }

    /// Import a user-picked image into Application Support so it survives the
    /// original file being moved or deleted.
    func setBackgroundImage(from url: URL) {
        backgroundImageError = nil
        do {
            let data = try Data(contentsOf: url)
            guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
                backgroundImageError = "无法读取这张图片，请换一张试试。"
                return
            }

            let target = backgroundImageURL
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: target, options: .atomic)

            backgroundImage = image
            backgroundImageName = url.lastPathComponent
            defaults.set(url.lastPathComponent, forKey: Key.backgroundImageName)
        } catch {
            backgroundImageError = "读取图片失败：\(error.localizedDescription)"
        }
    }

    func clearBackgroundImage() {
        backgroundImage = nil
        backgroundImageName = nil
        backgroundImageError = nil
        defaults.removeObject(forKey: Key.backgroundImageName)
        try? FileManager.default.removeItem(at: backgroundImageURL)
    }

    func dismissBackgroundImageError() {
        backgroundImageError = nil
    }

    // MARK: - Private

    private func beginRestore() {
        guard phase == .breaking else { return }
        phase = .restoring
        overlay.dismiss(fadeOut: fadeOutSeconds) { [weak self] in
            self?.finishBreak()
        }
    }

    private func finishBreak() {
        guard phase == .breaking || phase == .restoring else { return }
        if isEnabled {
            // Leave .restoring before restarting the timer; startCountdown()
            // intentionally refuses to run while a break is still active.
            phase = .idle
            startCountdown()
        } else {
            phase = .paused
            remaining = intervalSeconds
            nextBreakDate = nil
        }
    }

    private func startCountdown() {
        guard phase != .breaking, phase != .restoring, isEnabled else { return }

        stopTimer()
        phase = .idle

        let seconds = intervalSeconds
        remaining = seconds
        nextBreakDate = Date().addingTimeInterval(seconds)

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func pauseCountdown() {
        guard phase == .idle else { return }
        if let nextBreakDate {
            remaining = max(0, nextBreakDate.timeIntervalSinceNow)
        }
        stopTimer()
        phase = .paused
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        nextBreakDate = nil
    }

    private func tick() {
        guard phase == .idle, let nextBreakDate else { return }
        let left = nextBreakDate.timeIntervalSinceNow
        if left <= 0 {
            triggerBreak()
        } else {
            remaining = left
        }
    }

    var backgroundImageURL: URL {
        supportDirectory.appendingPathComponent("background.image", isDirectory: false)
    }

    private static var applicationSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    static var defaultSupportDirectory: URL {
        applicationSupportRoot.appendingPathComponent("Eyes Protecter", isDirectory: true)
    }

    private static var legacySupportDirectory: URL {
        applicationSupportRoot.appendingPathComponent("Move Ur Eyes", isDirectory: true)
    }

    /// One-time migration from the pre-2.0 bundle id and Application Support folder.
    private static func migrateLegacyDataIfNeeded(defaults: UserDefaults, supportDirectory: URL) {
        guard defaults.object(forKey: migrationMarker) == nil else { return }
        defer { defaults.set(true, forKey: migrationMarker) }

        // Never overwrite settings that already exist in the new domain.
        guard defaults.object(forKey: Key.intervalMinutes) == nil else { return }

        let legacyDefaults = UserDefaults(suiteName: "com.guorui.moveureyes")
        let keys = [
            Key.intervalMinutes,
            Key.message,
            Key.fadeInSeconds,
            Key.fadeOutSeconds,
            Key.isEnabled,
            Key.showCountdown,
            Key.backgroundImageName
        ]
        if let legacyDefaults {
            for key in keys {
                if let value = legacyDefaults.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }

        if defaults.string(forKey: Key.message) == legacyDefaultMessage {
            defaults.set(defaultMessage, forKey: Key.message)
        }

        let legacyImage = legacySupportDirectory.appendingPathComponent("background.image")
        let newImage = supportDirectory.appendingPathComponent("background.image")
        if FileManager.default.fileExists(atPath: legacyImage.path),
           !FileManager.default.fileExists(atPath: newImage.path) {
            try? FileManager.default.createDirectory(
                at: supportDirectory,
                withIntermediateDirectories: true
            )
            try? FileManager.default.copyItem(at: legacyImage, to: newImage)
        }
    }

    static func timeString(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
