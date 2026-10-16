// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import SwiftUI

struct LanguagePickerRow: View {
    @Bindable private var localization = Localization.shared

    var body: some View {
        HStack(spacing: 9) {
            Badge(on: true) {
                Image(systemName: "globe").font(.system(size: 12, weight: .medium))
            }
            Picker(L("Language"), selection: $localization.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language == .system ? L("Follow System") : language.displayName)
                        .tag(language)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 13))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
