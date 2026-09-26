import Foundation

/// 調整用の値。変更したら bash scripts/build-app.sh で再ビルドする
enum Config {
    /// About パネルに載せるリポジトリの URL
    static let repositoryURL = URL(string: "https://github.com/yotashiraishi/DisplayColourFilter")!

    /// システム側(universalaccessd)がディスプレイ構成の変更などで全ディスプレイ共通のフィルターを上書きしたあと、
    /// このアプリのディスプレイ別設定を掛け直すタイミング(きっかけからの秒数)。
    /// システム側の処理より後に適用したいので、少しずつずらして複数回掛け直す
    /// (実測ではカラーフィルタ設定の変更通知から約0.27秒後と約0.51秒後の2回、システム側が上書きしてくる)
    static let reapplyDelays: [TimeInterval] = [0.3, 0.6, 1.0, 3.0]

    /// 強さスライダーの範囲(システム設定と同じ 0.25〜1.0)
    static let intensityRange: ClosedRange<Double> = 0.25...1.0

    /// フィルター種類ごとの強さの初期値(システム設定の初期値と同じ)
    static let defaultIntensities: [FilterType: Double] = [
        .grayscale: 1.0,
        .redGreen: 0.5,
        .greenRed: 0.5,
        .blueYellow: 0.5,
        .colorTint: 0.4,
    ]

    /// 初めて接続したディスプレイで選ばれているフィルターの種類
    static let defaultFilterType: FilterType = .grayscale

    /// カラーティントの色合いの初期値(0〜1。0 と 1 はどちらも赤。システム設定の初期値は 1)
    static let defaultHue: Double = 1.0

    /// 受け取ったら掛け直すシステムの通知(カラーフィルタ設定・アクセシビリティ設定の変更。
    /// universalaccessd はこれらを受けて全ディスプレイ共通のフィルターを掛け直すため)
    static let systemSettingsNotifications = [
        "com.apple.mediaaccessibility.displayFilterSettingsChanged",
        "com.apple.universalaccess.screenGrayscaleDidChange",
        "com.apple.universalaccess.screenPolarityDidChange",
        "com.apple.UAContrastDidChange",
    ]
}
