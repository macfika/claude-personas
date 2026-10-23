// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import AppKit

// Only installedVersion needs this symbol; the fixture never reads the real application.
func realClaudeApp() -> URL { URL(fileURLWithPath: "/nonexistent-test-app") }

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let config = root.appendingPathComponent("config.json")
var observed: NSRunningApplication?
var launchError: Error?
let configuration = NSWorkspace.OpenConfiguration()
configuration.arguments = [config.path]
NSWorkspace.shared.openApplication(at: root.appendingPathComponent("ExitFixture.app"), configuration: configuration) { app, error in
    observed = app
    launchError = error
}
let deadline = Date().addingTimeInterval(15)
while observed == nil && launchError == nil && Date() < deadline {
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
}
guard let app = observed else {
    print("FAIL fixture launch (requires a macOS graphical login session)")
    exit(2)
}
defer { if !app.isTerminated { app.terminate() } }
// This is the same eager snapshot used by Engine.refresh while a profile is running.
let snapshot = UpdateWatch.ProcessSnapshot(app: app, observedAt: Date())
while !app.isTerminated && Date() < deadline {
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
}
guard app.isTerminated else { print("FAIL fixture exit"); exit(2) }
let reason = UpdateWatch.quitForUpdate(config: config, launchedAt: snapshot.launchedAt, stoppedAt: Date())
print(reason == true ? "PASS" : "FAIL", "real process update exit recognized from live snapshot")
exit(reason == true ? 0 : 1)
