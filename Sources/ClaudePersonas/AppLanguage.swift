// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    @MainActor var displayName: String {
        switch self {
        case .system: L("Follow System")
        case .simplifiedChinese: "中文（简体）"
        case .traditionalChinese: "中文（繁體）"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .english: "English"
        }
    }

    /// Respect preference order and Chinese script/region variants; unsupported lists use English.
    static func resolve(_ preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let parts = identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-")
            switch parts.first {
            case "zh":
                if parts.contains("hans") { return .simplifiedChinese }
                if parts.contains("hant") || parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) {
                    return .traditionalChinese
                }
                return .simplifiedChinese
            case "ja": return .japanese
            case "ko": return .korean
            case "en": return .english
            default: continue
            }
        }
        return .english
    }
}
