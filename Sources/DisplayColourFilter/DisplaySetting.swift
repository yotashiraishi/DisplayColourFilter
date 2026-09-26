import Foundation

/// フィルターの種類(値は MediaAccessibility の種別番号と同じ)
enum FilterType: Int, Codable, CaseIterable, Identifiable {
    case grayscale = 1
    case redGreen = 2
    case greenRed = 4
    case blueYellow = 8
    case colorTint = 16

    var id: Int { rawValue }

    /// メニューに出す名前(システム設定の表記に合わせる。日本語は ja.lproj/Localizable.strings)
    var title: String {
        switch self {
        case .grayscale: String(localized: "Greyscale")
        case .redGreen: String(localized: "Red/Green filter (Protanopia)")
        case .greenRed: String(localized: "Green/Red filter (Deuteranopia)")
        case .blueYellow: String(localized: "Blue/Yellow filter (Tritanopia)")
        case .colorTint: String(localized: "Colour Tint")
        }
    }
}

/// ディスプレイ1台ぶんの設定
struct DisplaySetting: Codable, Equatable {
    var isEnabled = false
    var type = Config.defaultFilterType
    /// 種類ごとの強さ(まだ触っていない種類は Config.defaultIntensities を使う)
    var intensities: [FilterType: Double] = [:]
    /// カラーティントの色合い(0〜1)
    var hue = Config.defaultHue

    /// 今選んでいる種類の強さ
    var intensity: Double {
        get { intensities[type] ?? Config.defaultIntensities[type] ?? Config.intensityRange.upperBound }
        set { intensities[type] = newValue }
    }
}
