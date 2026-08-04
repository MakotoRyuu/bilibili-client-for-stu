import SwiftUI
import Observation

/// 界面外观：亮 / 暗 / 跟随系统。选择持久化到 UserDefaults，重启保留。
@Observable
final class ThemeStore {
    enum Appearance: String, CaseIterable {
        case system
        case light
        case dark

        var title: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }

        var systemImage: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }

        /// 映射到 SwiftUI 的 colorScheme；system 交还系统（nil）。
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    private let storageKey = "bili.appearance.v1"

    var appearance: Appearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: storageKey)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        appearance = raw.flatMap(Appearance.init) ?? .system
    }

    /// 在 浅色 → 深色 → 跟随系统 之间循环切换。
    func cycle() {
        let all = Appearance.allCases
        if let idx = all.firstIndex(of: appearance) {
            appearance = all[(idx + 1) % all.count]
        }
    }
}
