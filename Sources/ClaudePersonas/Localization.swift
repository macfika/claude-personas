// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import Foundation
import Observation

@MainActor
@Observable
final class Localization {
    static let shared = Localization(observesSystemChanges: true)
    static let preferenceKey = "appLanguage"

    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            defaults.set(language.rawValue, forKey: Self.preferenceKey)
            onChange?()
        }
    }
    private(set) var systemLanguages: [String]
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bundles: [AppLanguage: Bundle]

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    init(defaults: UserDefaults = .standard, systemLanguages: [String] = Locale.preferredLanguages,
         observesSystemChanges: Bool = false) {
        self.defaults = defaults
        self.systemLanguages = systemLanguages
        let saved = defaults.string(forKey: Self.preferenceKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
        if isDemo, let preview = ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_LANGUAGE"].flatMap(AppLanguage.init(rawValue:)) {
            language = preview
        } else {
            language = saved
        }
        bundles = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.filter { $0 != .system }.compactMap { language in
            guard let path = Self.resourceBundle.path(forResource: language.rawValue, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { return nil }
            return (language, bundle)
        })
        if observesSystemChanges {
            // The shared instance lives for the process lifetime. The notification closure retains it weakly.
            NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                                                   object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updateSystemLanguages(Locale.preferredLanguages) }
            }
        }
    }

    var resolvedLanguage: AppLanguage { language == .system ? AppLanguage.resolve(systemLanguages) : language }
    var locale: Locale { Locale(identifier: resolvedLanguage.rawValue) }

    func updateSystemLanguages(_ languages: [String]) {
        systemLanguages = languages
        if language == .system { onChange?() }
    }

    func text(_ key: String, arguments: [String] = []) -> String {
        let fallback = bundles[.english]?.localizedString(forKey: key, value: key, table: nil) ?? key
        let format = bundles[resolvedLanguage]?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments.map { $0 as CVarArg })
    }
}

/// All formatting parameters are strings so translations can safely reorder named values with %n$@.
@MainActor
func L(_ key: String, _ arguments: String...) -> String {
    Localization.shared.text(key, arguments: arguments)
}
