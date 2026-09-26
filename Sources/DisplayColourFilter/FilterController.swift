import AppKit
import ColorSync
import Observation
import PrivateDisplayFilter

/// 接続中のディスプレイ
struct ConnectedDisplay: Identifiable {
    let id: CGDirectDisplayID
    /// 設定の保存キー(ディスプレイ固有の UUID。つなぎ直しても変わらない)
    let uuid: String
    let name: String
}

/// Darwin 通知(C のコールバック)からメインスレッドへ橋渡しするための通知名
private let systemSettingsChanged = Notification.Name("DisplayColourFilter.systemSettingsChanged")

/// ディスプレイごとのフィルター設定を保存し、各ディスプレイに適用する
@MainActor
@Observable
final class FilterController {
    /// 必要な非公開 API が使えるか
    let isAvailable = PDFIsAvailable()
    private(set) var displays: [ConnectedDisplay] = []
    /// ディスプレイの UUID → 設定
    private var settings: [String: DisplaySetting] = [:]
    private var reapplyTask: Task<Void, Never>?

    private static let settingsKey = "displaySettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode([String: DisplaySetting].self, from: data) {
            settings = saved
        }
    }

    func start() {
        guard isAvailable else { return }
        reloadDisplays()
        applyAll()
        // ログイン直後などはシステム側が後から全ディスプレイ共通のフィルターを掛けてくるので掛け直す
        scheduleReapply()
        observeSystemEvents()
    }

    func setting(for display: ConnectedDisplay) -> DisplaySetting {
        settings[display.uuid] ?? DisplaySetting()
    }

    func update(_ display: ConnectedDisplay, _ change: (inout DisplaySetting) -> Void) {
        var setting = setting(for: display)
        change(&setting)
        settings[display.uuid] = setting
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
        apply(setting, to: display.id)
    }

    /// 全ディスプレイをシステム設定どおりの状態に戻す(アプリ終了時)
    func restoreSystemState() {
        guard isAvailable else { return }
        PDFRestoreSystemState()
    }

    private func apply(_ setting: DisplaySetting, to displayID: CGDirectDisplayID) {
        var matrix: [Float] = [1, 0, 0, 0, 1, 0, 0, 0, 1] // フィルター無し
        if setting.isEnabled {
            PDFMakeFilterMatrix(Int32(setting.type.rawValue), setting.intensity, setting.hue, &matrix)
        }
        PDFApplyMatrixToDisplay(displayID, matrix)
    }

    private func applyAll() {
        for display in displays {
            apply(setting(for: display), to: display.id)
        }
    }

    private func reloadDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = CGDirectDisplayID(number.uint32Value)
            guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
            return ConnectedDisplay(id: displayID, uuid: CFUUIDCreateString(nil, uuid) as String, name: screen.localizedName)
        }
    }

    /// システム側の上書きより後になるよう、時間をずらして何度か掛け直す
    private func scheduleReapply() {
        reapplyTask?.cancel()
        reapplyTask = Task {
            var elapsed: TimeInterval = 0
            for delay in Config.reapplyDelays {
                try? await Task.sleep(for: .seconds(delay - elapsed))
                if Task.isCancelled { return }
                elapsed = delay
                reloadDisplays()
                applyAll()
            }
        }
    }

    private func observeSystemEvents() {
        // ディスプレイの接続・解像度変更など
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reloadDisplays()
                self?.applyAll()
                self?.scheduleReapply()
            }
        }

        // スリープ解除・ユーザー切り替えからの復帰
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleReapply() }
            }
        }

        // システムのカラーフィルタ・アクセシビリティ設定の変更(Darwin 通知と分散通知の両方で届きうる)
        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        for name in Config.systemSettingsNotifications {
            CFNotificationCenterAddObserver(darwinCenter, nil, { _, _, _, _, _ in
                NotificationCenter.default.post(name: systemSettingsChanged, object: nil)
            }, name as CFString, nil, .deliverImmediately)

            DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleReapply() }
            }
        }
        NotificationCenter.default.addObserver(forName: systemSettingsChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleReapply() }
        }
    }
}
