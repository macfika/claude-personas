// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let config = URL(fileURLWithPath: CommandLine.arguments[1])
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    do {
        let data = try JSONSerialization.data(withJSONObject: ["lastQuitCleanup": [
            "for_update": true, "quit_epoch_ms": Date().timeIntervalSince1970 * 1000]])
        try data.write(to: config)
    } catch { exit(2) }
    app.terminate(nil)
}
app.run()
