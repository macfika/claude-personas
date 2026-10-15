// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import SwiftUI

struct MenuView: View {
    @State private var contentHeight: CGFloat = 320

    var body: some View {
        ScrollView {
            MenuContent()
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { contentHeight = $0 }
        }
        .scrollIndicators(.automatic)
        .frame(width: 300, height: min(contentHeight, max(200, (NSScreen.main?.visibleFrame.height ?? 800) - 60)))
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { size in
            PanelController.shared.resize(to: size)
        }
    }
}
