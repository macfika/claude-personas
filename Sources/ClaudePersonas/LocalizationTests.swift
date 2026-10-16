// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import Foundation

@MainActor
enum LocalizationTests {
    static func run() -> Bool {
        var ok = true
        func check(_ name: String, _ value: Bool) {
            print(value ? "PASS" : "FAIL", name)
            ok = ok && value
        }
        let cases: [([String], AppLanguage)] = [
            (["zh-CN"], .simplifiedChinese), (["zh-SG"], .simplifiedChinese),
            (["zh-Hans-HK"], .simplifiedChinese), (["zh"], .simplifiedChinese),
            (["zh-TW"], .traditionalChinese), (["zh-HK"], .traditionalChinese),
            (["zh-MO"], .traditionalChinese), (["zh-Hant-CN"], .traditionalChinese),
            (["zh_Hant_TW"], .traditionalChinese), (["ja-JP"], .japanese),
            (["ko-KR"], .korean), (["en-GB"], .english),
            (["fr-FR", "ja-JP", "en"], .japanese), (["fr", "de"], .english), ([], .english),
        ]
        for (preferences, expected) in cases {
            check("language resolution \(preferences)", AppLanguage.resolve(preferences) == expected)
        }

        let suite = "com.macfika.claude-personas.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return false }
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = Localization(defaults: defaults, systemLanguages: ["ja-JP"])
        check("first launch follows system", model.language == .system && model.resolvedLanguage == .japanese)
        var changes = 0
        model.onChange = { changes += 1 }
        model.language = .traditionalChinese
        check("manual language overrides system", model.resolvedLanguage == .traditionalChinese)
        check("language change notifies AppKit", changes == 1)
        let reloaded = Localization(defaults: defaults, systemLanguages: ["en-US"])
        check("language selection persists", reloaded.language == .traditionalChinese)
        model.updateSystemLanguages(["ko-KR"])
        check("system change preserves manual selection", model.resolvedLanguage == .traditionalChinese)
        model.language = .system
        check("return to follow system", model.resolvedLanguage == .korean)
        model.updateSystemLanguages(["zh-CN"])
        check("system preference changes refresh language", model.resolvedLanguage == .simplifiedChinese)
        defaults.set("unsupported", forKey: Localization.preferenceKey)
        let invalid = Localization(defaults: defaults, systemLanguages: ["ja-JP"])
        check("invalid stored language follows system", invalid.language == .system && invalid.resolvedLanguage == .japanese)

        func table(_ language: AppLanguage, _ name: String) -> [String: String]? {
            guard let folder = Localization.resourceBundle.url(forResource: language.rawValue, withExtension: "lproj"),
                  let data = try? Data(contentsOf: folder.appendingPathComponent(name + ".strings")) else { return nil }
            return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: String]
        }
        guard let english = table(.english, "Localizable"), !english.isEmpty else {
            check("English resource catalog is packaged", false)
            return false
        }
        check("English catalog includes UI and notices", english.count >= 100 && english["Language"] != nil)
        let placeholder = try? NSRegularExpression(pattern: #"%(?:([1-9][0-9]*)\$)?@"#)
        func argumentPositions(_ value: String) -> [Int] {
            guard let placeholder else { return [] }
            return placeholder.matches(in: value, range: NSRange(value.startIndex..., in: value)).enumerated().map { index, match in
                if let range = Range(match.range(at: 1), in: value), let position = Int(value[range]) { return position }
                return index + 1
            }.sorted()
        }
        for language in AppLanguage.allCases where language != .system {
            guard let translated = table(language, "Localizable") else {
                check("\(language.rawValue) catalog is packaged", false)
                continue
            }
            check("\(language.rawValue) complete key coverage", Set(translated.keys) == Set(english.keys))
            check("\(language.rawValue) nonempty translations", translated.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            check("\(language.rawValue) formatting arguments preserved", english.allSatisfy { key, value in
                translated[key].map { argumentPositions($0) == argumentPositions(value) } ?? false
            })
            check("\(language.rawValue) permission description packaged", table(language, "InfoPlist")?["NSAppleEventsUsageDescription"]?.isEmpty == false)
            model.language = language
            check("\(language.rawValue) actual bundle lookup", model.text("Language") == translated["Language"])
            let account = "工作 100% %@ 🌸"
            let rendered = model.text("Open %@", arguments: [account])
            check("\(language.rawValue) user values preserved", rendered.contains(account) && rendered != "Open %@")
            check("\(language.rawValue) missing key fallback", model.text("missing.localization.key") == "missing.localization.key")
        }
        model.language = .simplifiedChinese
        let initial = model.text("Settings")
        model.language = .japanese
        check("changing language updates existing model", initial != model.text("Settings"))
        return ok
    }
}
