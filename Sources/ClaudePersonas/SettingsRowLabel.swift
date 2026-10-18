// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import SwiftUI

/// Shared geometry keeps setting and update controls aligned in every language.
struct SettingsRowLabel: View {
    let title: String
    let symbol: String
    let on: Bool
    var hint: String? = nil
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 9) {
            Badge(on: on) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(on ? 1 : 0.75))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            if let hint {
                Text(hint).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .modifier(HoverBackground(radius: 8))
    }
}
