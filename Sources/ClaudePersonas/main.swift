// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
// ClaudePersonas: menu bar manager for several Claude desktop instances, one per profile.
// Each profile is a separate --user-data-dir, so each one keeps its own account and chats.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
let websiteURL = URL(string: "https://github.com/macfika/claude-personas")!
let supportURL = URL(string: "https://github.com/macfika/claude-personas/issues")!
let claudeBundleID = "com.anthropic.claudefordesktop"

// Claude.app itself. ClaudePersonas's per-profile copies share its bundle id, so never look it up by id alone.
func realClaudeApp() -> URL {
    let standard = URL(fileURLWithPath: "/Applications/Claude.app")
    if FileManager.default.fileExists(atPath: standard.path) { return standard }
    let ours = Runtimes.folder.standardizedFileURL.path
    return NSWorkspace.shared.urlsForApplications(withBundleIdentifier: claudeBundleID)
        .first { !$0.standardizedFileURL.path.hasPrefix(ours) } ?? standard
}
let supportDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
let isPreview = ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_PREVIEW"] != nil
// Releases are signed in CI with the matching private key (repo secret UPDATE_SIGNING_KEY).
let updatePublicKey = Bundle.main.object(forInfoDictionaryKey: "UpdatePublicKey") as? String ?? ""
// Command-line modes (--list, --selftest-*, ...) only read; the menu bar app owns the profile list.
let isCLI = CommandLine.arguments.count > 1
let isDemo = ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_DEMO"] != nil   // sample profiles for README screenshots

extension Color {
    static let claude = Color(red: 0.851, green: 0.467, blue: 0.341)   // #D97757
}

extension NSColor {
    static let claude = NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)
}

// MARK: - Profiles


func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

let args = CommandLine.arguments
if args.count == 2, args[1] == "--list" {
    // Prints each profile and whether it runs, for a quick check from the terminal.
    MainActor.assumeIsolated {
        let e = Engine.shared
        e.refresh()
        for p in e.profiles {
            let state = e.frontID == p.id ? "active" : e.isRunning(p) ? "running" : "-"
            print("\(e.isRunning(p) ? "●" : "○") \(p.name)\t\(state)\t\(Palette.colors[p.colorIndex].name)\t\(p.dir ?? "(default)")")
        }
    }
    exit(0)
}
if args.count == 2, args[1] == "--selftest-update" {
    // Checks which profiles get reopened around a Claude update.
    let a = UUID(), b = UUID(), c = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let quitAt = [a: t0.addingTimeInterval(-2), b: t0.addingTimeInterval(-400), c: t0.addingTimeInterval(20)]
    let cases: [(String, Bool, Date, Set<UUID>)] = [
        ("relaunched, 30 s later", true, t0.addingTimeInterval(30), [a, c]),
        ("relaunched, c quit 1 s ago", true, t0.addingTimeInterval(21), [a]),
        ("no relaunch (quit on purpose)", false, t0.addingTimeInterval(30), []),
    ]
    var ok = true
    for (name, relaunched, now, want) in cases {
        let got = UpdateWatch.due(quitAt: quitAt, updatedAt: t0, relaunched: relaunched, now: now)
        print(got == want ? "PASS" : "FAIL", name)
        ok = ok && got == want
    }
    let stops = [t0.addingTimeInterval(-3), t0.addingTimeInterval(-1)]
    let strays: [(String, Date?, Date?, [Date], Bool)] = [
        ("stray: default starts right after profiles stop", t0.addingTimeInterval(2), nil, stops, true),
        ("kept: default also stopped for the update", t0.addingTimeInterval(2), t0.addingTimeInterval(-2), stops, false),
        ("kept: default opened a minute later by hand", t0.addingTimeInterval(60), nil, stops, false),
        ("kept: default running since before the update", t0.addingTimeInterval(-3600), nil, stops, false),
        ("kept: no profile stopped around the update", t0.addingTimeInterval(2), nil, [], false),
    ]
    for (name, launch, dstop, ps, want) in strays {
        let got = UpdateWatch.isStrayDefault(defaultLaunch: launch, defaultStop: dstop, profileStops: ps, updatedAt: t0)
        print(got == want ? "PASS" : "FAIL", name)
        ok = ok && got == want
    }
    let opens: [(String, String?, Bool, [String])] = [
        ("default, nothing running", nil, false, ["-a", "/A/Claude.app"]),
        ("default, another account running", nil, true, ["-n", "-a", "/A/Claude.app"]),
        ("profile", "/x/Claude-Work", true, ["-n", "-a", "/A/Claude.app", "--args", "--user-data-dir=/x/Claude-Work"]),
    ]
    for (name, dir, any, want) in opens {
        let got = Launch.openArgs(app: "/A/Claude.app", dir: dir, anyClaudeRunning: any)
        print(got == want ? "PASS" : "FAIL", name)
        ok = ok && got == want
    }
    exit(ok ? 0 : 1)
}
if args.count == 2, args[1] == "--check-update" || args[1] == "--update-now" {
    // --check-update prints the latest release; --update-now also installs it over this app bundle.
    let install = args[1] == "--update-now"
    let sem = DispatchSemaphore(value: 0)
    var code: Int32 = 0
    Task.detached {
        do {
            guard let r = try await Updater.latest() else { print("no release found"); code = 1; sem.signal(); return }
            let newer = Updater.isNewer(r.version, than: Updater.currentVersion)
            print("installed \(Updater.currentVersion), latest \(r.version)\(newer ? ", update available" : ", up to date")")
            if install && newer {
                try await Updater.install(r, at: Bundle.main.bundleURL)
                print("installed \(r.version) at \(Bundle.main.bundleURL.path)")
            }
        } catch { print("failed: \(error)"); code = 1 }
        sem.signal()
    }
    sem.wait()
    exit(code)
}
if args.count == 3, args[1] == "--sign-update" {
    // CI: prints the base64 signature of a release zip; the key comes from CLAUDE_PERSONAS_SIGNING_KEY.
    guard let key = ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_SIGNING_KEY"], !key.isEmpty,
          let data = FileManager.default.contents(atPath: args[2]), let sig = try? UpdateSignature.sign(data, keyBase64: key)
    else { FileHandle.standardError.write(Data("signing failed\n".utf8)); exit(1) }
    print(sig)
    exit(0)
}
if args.count == 4, args[1] == "--verify-update" {
    let data = FileManager.default.contents(atPath: args[2]) ?? Data()
    let sig = (try? String(contentsOfFile: args[3], encoding: .utf8)) ?? ""
    let ok = UpdateSignature.verify(data, signatureBase64: sig)
    print(ok ? "valid" : "INVALID")
    exit(ok ? 0 : 1)
}
if args.count == 2, args[1] == "--selftest-profiles" {
    var ok = true
    func check(_ name: String, _ cond: Bool) { print(cond ? "PASS" : "FAIL", name); ok = ok && cond }
    let target: [String: Any] = ["preferences": ["x": 1], "mcpServers": ["a": ["command": "old"], "keep": ["command": "k"]]]
    let merged = MCP.merge(target, adding: ["a": ["command": "new"], "b": ["command": "b"]])
    let m = merged["mcpServers"] as? [String: [String: String]] ?? [:]
    check("merge replaces same name", m["a"]?["command"] == "new")
    check("merge adds new server", m["b"] != nil)
    check("merge keeps other servers", m["keep"] != nil)
    check("merge keeps other keys", merged["preferences"] != nil)
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mc-clone-\(UUID().uuidString)")
    let src = tmp.appendingPathComponent("Claude"), dst = tmp.appendingPathComponent("Claude-Copy")
    try? FileManager.default.createDirectory(at: src.appendingPathComponent("Local Storage"), withIntermediateDirectories: true)
    try? Data("chats".utf8).write(to: src.appendingPathComponent("Local Storage/db"))
    try? FileManager.default.createSymbolicLink(atPath: src.appendingPathComponent("SingletonLock").path, withDestinationPath: "host-123")
    check("clone succeeds", Duplicate.clone(from: src.path, to: dst.path))
    check("clone copies data", (try? String(contentsOf: dst.appendingPathComponent("Local Storage/db"), encoding: .utf8)) == "chats")
    check("clone drops lock", (try? FileManager.default.destinationOfSymbolicLink(atPath: dst.appendingPathComponent("SingletonLock").path)) == nil)
    check("clone refuses existing destination", !Duplicate.clone(from: src.path, to: dst.path))
    let alias = tmp.appendingPathComponent("Claude-Old"), aliasCopy = tmp.appendingPathComponent("Claude-AliasCopy")
    try? FileManager.default.createSymbolicLink(at: alias, withDestinationURL: src)
    check("clone resolves source symlink", Duplicate.clone(from: alias.path, to: aliasCopy.path))
    check("clone through symlink creates real directory", ((try? FileManager.default.attributesOfItem(atPath: aliasCopy.path))?[.type] as? FileAttributeType) == .typeDirectory)
    check("source lock remains after symlink clone", (try? FileManager.default.destinationOfSymbolicLink(atPath: src.appendingPathComponent("SingletonLock").path)) != nil)
    try? Data("changed".utf8).write(to: aliasCopy.appendingPathComponent("Local Storage/db"))
    check("symlink clone is independent", (try? String(contentsOf: src.appendingPathComponent("Local Storage/db"), encoding: .utf8)) == "chats")
    check("clone refuses destination inside source", !Duplicate.clone(from: src.path, to: src.appendingPathComponent("Nested").path))

    let pa = Profile(name: "A", dir: tmp.appendingPathComponent("Claude-A").path)
    let pb = Profile(name: "B", dir: tmp.appendingPathComponent("Claude-B").path)
    try? FileManager.default.createDirectory(atPath: pa.dir!, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: pb.dir!, withIntermediateDirectories: true)
    try? Data(#"{"mcpServers":{"fs":{"command":"npx","args":["server-fs","/tmp"]}}}"#.utf8).write(to: MCP.configURL(pa))
    try? Data(#"{"preferences":{"x":1}}"#.utf8).write(to: MCP.configURL(pb))
    let copied = (try? MCP.copy(from: pa, to: pb)) ?? -1
    check("copy reports 1 server", copied == 1)
    check("copy writes server into target", MCP.servers(pb)["fs"] != nil)
    check("copy keeps target preferences", ((try? MCP.read(MCP.configURL(pb)))?["preferences"]) != nil)
    let backups = (try? FileManager.default.contentsOfDirectory(atPath: pb.dir!))?.filter { $0.contains(".bak-") } ?? []
    check("copy leaves a backup", backups.count == 1)
    try? Data("not json".utf8).write(to: MCP.configURL(pb))
    check("copy refuses a broken target file", (try? MCP.copy(from: pa, to: pb)) == nil)
    let sup = tmp.appendingPathComponent("Support").path
    try? FileManager.default.createDirectory(atPath: sup + "/Claude-Work/Local Storage", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: sup + "/Claude-3p", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: sup + "/Claude-Moonsun", withIntermediateDirectories: true)
    check("candidates skip Claude-3p", Folders.candidates(in: sup).map { URL(fileURLWithPath: $0).lastPathComponent } == ["Claude-Moonsun", "Claude-Work"])
    let tgt = Folders.target(for: "Augura", current: sup + "/Claude-Work", in: sup)
    check("target follows the name", tgt == sup + "/Claude-Augura")
    check("no target when already aligned", Folders.target(for: "Moonsun", current: sup + "/Claude-Moonsun", in: sup) == nil)
    check("no target onto another profile's folder", Folders.target(for: "Moonsun", current: sup + "/Claude-Work", in: sup) == nil)
    check("move succeeds", Folders.move(sup + "/Claude-Work", to: sup + "/Claude-Augura"))
    check("old path is a symlink to the new one", (try? FileManager.default.destinationOfSymbolicLink(atPath: sup + "/Claude-Work")) == sup + "/Claude-Augura")
    check("candidates skip the symlink", Folders.candidates(in: sup).map { URL(fileURLWithPath: $0).lastPathComponent } == ["Claude-Augura", "Claude-Moonsun"])
    check("canonical resolves the old path", Folders.canonical(sup + "/Claude-Work") == Folders.canonical(sup + "/Claude-Augura"))
    check("no target onto a leftover symlink", Folders.target(for: "Work", current: sup + "/Claude-Augura", in: sup) == nil)
    try? FileManager.default.removeItem(at: tmp)
    exit(ok ? 0 : 1)
}
if args.count == 2, args[1] == "--selftest-signin" {
    // Lines taken from Claude's main.log on 2026-10-10.
    let launchBounce = ["[info] claude.ai account active and logged in", "[info] [account] Navigated to /logout, synthesizing logged-out"]
    let browser = ["[info] [Auth] Using system browser for: /login/app-google-auth"]
    let back = ["[info] claudeURLHandler: login loadURL superseded (teardown race)"]
    let loggedIn = ["[info] claude.ai account active and logged in"]
    let sheet = ["[info] [Auth] Not the claude:// handler; keeping ASWebAuth",
                 "[info] [Auth] Starting ASWebAuth for: /login/app-google-auth (default browser: safari)"]
    let sheetDone = ["[info] [Auth] ASWebAuth completed: {"]
    let cases: [(String, [String], Bool, Bool)] = [
        ("launch 'logged in' before /logout is not done", launchBounce, false, false),
        ("browser step alone is not done", browser, false, false),
        ("login link handled is done", back, false, true),
        ("logged in after browser step is done", browser + loggedIn, false, true),
        ("browser seen in an earlier read, logged in now", loggedIn, true, true),
        ("in-window sheet started is not done", sheet, false, false),
        ("in-window sheet completed is done", sheet + sheetDone, false, true),
    ]
    var ok = true
    for (name, lines, saw, want) in cases {
        let got = SignInLog.scan(lines, sawBrowser: saw).done
        print(got == want ? "PASS" : "FAIL", name)
        ok = ok && got == want
    }
    exit(ok ? 0 : 1)
}
if args.count == 2, args[1] == "--selftest-launchers" {
    var ok = true
    func check(_ name: String, _ cond: Bool) { print(cond ? "PASS" : "FAIL", name); ok = ok && cond }
    let fm = FileManager.default
    let tmp = fm.temporaryDirectory.appendingPathComponent("mc-launchers-\(UUID().uuidString)")
    // Every invocation is isolated, including a direct CLI self-test without the test script.
    if ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_TEST_ROOT"]?.isEmpty != false {
        setenv("CLAUDE_PERSONAS_TEST_ROOT", tmp.appendingPathComponent("RuntimeTest").path, 1)
    }

    var work = Profile(name: "Work", dir: "/tmp/it's/Claude-Work", color: 1)
    let home = Profile(name: "Claude", dir: nil, color: 0)
    check("default app name", work.dockAppName == "Claude Work" && home.dockAppName == "Claude Default")
    var plain = work; plain.appName = " claude "
    check("an app is never named plain Claude", plain.dockAppName == "Claude Work")
    check("file name drops slashes", Launchers.fileName("A/B: C.") == "A-B- C.app")
    check("script asks ClaudePersonas first", Launchers.script(for: work).contains("claude-personas://open?profile=\(work.id.uuidString)"))
    check("script falls back with the quoted folder", Launchers.script(for: work).contains("'--user-data-dir=/tmp/it'\\''s/Claude-Work'"))
    check("default profile falls back without -n", Launchers.script(for: home).contains("exec /usr/bin/open -a \"$app\"\n"))
    check("fallback prefers the profile's own Claude", Launchers.script(for: work).contains(Runtimes.dir(work.id).path))
    var r = MainActor.assumeIsolated { Launchers.sync([work, home], in: tmp) }
    let apps = Launchers.installed(in: tmp)
    check("one app per profile", apps.count == 2 && r.failed.isEmpty)
    let workApp = tmp.appendingPathComponent("Claude Work.app")
    check("app named after the profile", apps[work.id]?.lastPathComponent == "Claude Work.app")
    check("script is executable", fm.isExecutableFile(atPath: workApp.path + "/Contents/MacOS/launch"))
    check("icon written", ((try? Data(contentsOf: workApp.appendingPathComponent("Contents/Resources/icon.icns")))?.count ?? 0) > 10_000)
    let before = (try? fm.attributesOfItem(atPath: workApp.path + "/Contents/Info.plist")[.modificationDate]) as? Date
    r = MainActor.assumeIsolated { Launchers.sync([work, home], in: tmp) }
    let after = (try? fm.attributesOfItem(atPath: workApp.path + "/Contents/Info.plist")[.modificationDate]) as? Date
    check("unchanged profile is not rewritten", before == after && r.moved.isEmpty)
    work.appName = "Claude Client"
    r = MainActor.assumeIsolated { Launchers.sync([work, home], in: tmp) }
    check("rename moves the app", r.moved.count == 1 && Launchers.installed(in: tmp)[work.id]?.lastPathComponent == "Claude Client.app")
    check("rename rewrites the app", r.rewritten.count == 1)
    work.color = 4
    r = MainActor.assumeIsolated { Launchers.sync([work, home], in: tmp) }
    check("recolor rewrites only that app", r.rewritten.map(\.lastPathComponent) == ["Claude Client.app"] && r.moved.isEmpty)
    check("renamed app carries the new name", Launchers.readInfo(tmp.appendingPathComponent("Claude Client.app"))?["CFBundleName"] as? String == "Claude Client")
    var twin = Profile(name: "Twin", dir: "/tmp/Claude-Twin", color: 2)
    twin.appName = "Claude Client"
    r = MainActor.assumeIsolated { Launchers.sync([work, home, twin], in: tmp) }
    var dot = work; dot.appName = "Claude."
    check("a name that becomes Claude.app gets a number", Launchers.fileName(dot.dockAppName) == "Claude.app"
          && MainActor.assumeIsolated { Launchers.sync([dot], in: tmp.appendingPathComponent("dot")) }.failed.isEmpty
          && Launchers.installed(in: tmp.appendingPathComponent("dot"))[dot.id]?.lastPathComponent == "Claude. 2.app")
    check("clashing names get a number", Launchers.installed(in: tmp)[twin.id]?.lastPathComponent == "Claude Client 2.app")
    try? fm.createDirectory(at: tmp.appendingPathComponent("Other.app"), withIntermediateDirectories: true)
    r = MainActor.assumeIsolated { Launchers.sync([home], in: tmp) }
    check("removed profiles lose their app", r.removed.count == 2 && Launchers.installed(in: tmp).count == 1)
    check("other apps in the folder stay", fm.fileExists(atPath: tmp.appendingPathComponent("Other.app").path))
    r = MainActor.assumeIsolated { Launchers.sync([], in: tmp) }
    check("turning the setting off removes every app", Launchers.installed(in: tmp).isEmpty && r.removed.count == 1)
    // Runtimes, against a fake Claude.app (the real folder isn't touched: these use explicit paths).
    func fakeClaude(_ v: String) -> URL {
        let c = tmp.appendingPathComponent("src-\(v)/Claude.app")
        try? fm.createDirectory(at: c.appendingPathComponent("Contents/Resources/fr.lproj"), withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleShortVersionString": v, "CFBundleIdentifier": claudeBundleID]
        try? PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: c.appendingPathComponent("Contents/Info.plist"))
        return c
    }
    let rp = Profile(name: "Runtime Test \(UUID().uuidString.prefix(6))", dir: "/tmp/x", color: 3)
    defer { try? fm.removeItem(at: Runtimes.dir(rp.id)) }
    let v1 = fakeClaude("1.0"), v2 = fakeClaude("2.0")
    let rt = Runtimes.ensure(rp, from: v1, running: { _ in false })
    check("runtime is cloned", rt != nil && Runtimes.version(rt!) == "1.0")
    check("runtime is named after the profile and wears its icon", Runtimes.current(rp.id)!.lastPathComponent == Launchers.fileName(rp.dockAppName)
          && Runtimes.hasLook(Runtimes.current(rp.id)!))
    check("runtime contents untouched", !fm.fileExists(atPath: Runtimes.current(rp.id)!.path + "/Contents/Resources/fr.lproj/InfoPlist.strings"))
    check("runtime Info.plist untouched", (try? Data(contentsOf: Runtimes.current(rp.id)!.appendingPathComponent("Contents/Info.plist")))
          == (try? Data(contentsOf: v1.appendingPathComponent("Contents/Info.plist"))))
    _ = Runtimes.ensure(rp, from: v2, running: { _ in true })
    check("running runtime is left alone", Runtimes.version(Runtimes.current(rp.id)!) == "1.0")
    var recolored = rp; recolored.color = 5
    let nameBefore = Runtimes.current(rp.id)!.lastPathComponent
    _ = Runtimes.ensure(recolored, from: v1, running: { _ in true })
    check("running runtime gets the new icon in place", ((try? String(contentsOf: Runtimes.stampURL(rp.id), encoding: .utf8)) ?? "").hasSuffix("|5")
          && Runtimes.current(rp.id)!.lastPathComponent == nameBefore)
    _ = Runtimes.ensure(rp, from: v2, running: { _ in false })
    check("closed runtime follows a Claude update", Runtimes.version(Runtimes.current(rp.id)!) == "2.0")
    _ = Runtimes.ensure(rp, from: v1, running: { _ in false })
    check("runtime ahead of Claude is kept", Runtimes.version(Runtimes.current(rp.id)!) == "2.0")
    var renamed = rp; renamed.appName = "Claude \"Quoted\""
    _ = Runtimes.ensure(renamed, from: v2, running: { _ in false })
    check("rename renames the bundle", Runtimes.current(rp.id)!.lastPathComponent == "Claude \"Quoted\".app")
    try? Data("1|2.0|old".utf8).write(to: Runtimes.stampURL(rp.id))
    _ = Runtimes.ensure(renamed, from: v1, running: { _ in false })
    check("a copy from an older format is rebuilt", Runtimes.version(Runtimes.current(rp.id)!) == "1.0")
    let others = ((try? fm.contentsOfDirectory(atPath: Runtimes.folder.path)) ?? [])
        .compactMap { UUID(uuidString: $0) }.filter { $0 != rp.id }
    Runtimes.prune(keeping: Set(others))   // only the test copy goes
    check("prune removes a closed runtime", !Runtimes.exists(rp.id))
    let ownerURL = Runtimes.dir(rp.id).appendingPathComponent("Claude X.app")
    check("a copy's bundle names its profile", Runtimes.owner(of: ownerURL) == rp.id
          && Runtimes.owner(of: URL(fileURLWithPath: "/Applications/Claude.app")) == nil)
    let entry = Dock.entry(for: URL(fileURLWithPath: "/Users/x/Applications/ClaudePersonas Launchers/Claude Work.app"))
    check("dock entry round-trips its path", Dock.path(of: entry) == "/Users/x/Applications/ClaudePersonas Launchers/Claude Work.app")
    try? fm.removeItem(at: tmp)
    exit(ok ? 0 : 1)
}
if args.count == 3, args[1] == "--export-profile-icon" {   // --export-profile-icon <out.png>, for README art
    MainActor.assumeIsolated {
        let tiles = Palette.colors.map { AppIcon.profile(256, color: $0.color, letter: "X") }
        let strip = NSImage(size: NSSize(width: 256 * tiles.count, height: 256), flipped: false) { _ in
            for (i, t) in tiles.enumerated() { t.draw(in: NSRect(x: i * 256, y: 0, width: 256, height: 256)) }
            return true
        }
        let rep = NSBitmapImageRep(data: strip.tiffRepresentation!)!
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[2]))
    }
    exit(0)
}
if args.count == 2, args[1] == "--selftest-signature" {
    let key = Curve25519.Signing.PrivateKey()
    let data = Data("Claude Personas signed release".utf8)
    let signature = try UpdateSignature.sign(data, keyBase64: key.rawRepresentation.base64EncodedString())
    let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
    var ok = true
    func check(_ name: String, _ result: Bool) { print(result ? "PASS" : "FAIL", name); ok = ok && result }
    check("signature round trip", UpdateSignature.verify(data, signatureBase64: signature, publicKeyBase64: publicKey))
    check("tampered payload rejected", !UpdateSignature.verify(data + Data([0]), signatureBase64: signature, publicKeyBase64: publicKey))
    check("wrong key rejected", !UpdateSignature.verify(data, signatureBase64: signature, publicKeyBase64: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()))
    check("missing key rejected", !UpdateSignature.verify(data, signatureBase64: signature, publicKeyBase64: ""))
    check("upstream key rejected", !UpdateSignature.verify(data, signatureBase64: signature, publicKeyBase64: "ovYVjB5Bst53pHaSwbk7KKX+JRAqv7zuponiduhHa+w="))
    check("own release URL trusted", Updater.trusted("https://github.com/macfika/claude-personas/releases/download/v1.0.0/ClaudePersonas.zip") != nil)
    check("upstream URL rejected", Updater.trusted("https://github.com/QuentinCar0n/multiclaude/releases/download/v1.0.0/MultiClaude.zip") == nil)
    check("other host rejected", Updater.trusted("https://example.com/macfika/claude-personas/releases/download/v1.0.0/ClaudePersonas.zip") == nil)
    check("insecure URL rejected", Updater.trusted("http://github.com/macfika/claude-personas/releases/download/v1.0.0/ClaudePersonas.zip") == nil)
    exit(ok ? 0 : 1)
}
if args.count == 2, args[1] == "--selftest-version" {
    let cases = [("1.2", "1.1", true), ("1.10", "1.9", true), ("1.2", "1.2", false), ("1.2", "1.2.1", false), ("2.0", "1.9.9", true)]
    var ok = true
    for (a, b, want) in cases {
        let got = Updater.isNewer(a, than: b)
        print(got == want ? "PASS" : "FAIL", a, ">", b, got)
        ok = ok && got == want
    }
    exit(ok ? 0 : 1)
}
if args.count == 2, args[1] == "--unregister-login" {
    try? SMAppService.mainApp.unregister()
    exit(0)
}
if args.count == 3, args[1] == "--export-iconset" {
    MainActor.assumeIsolated { AppIcon.exportIconset(to: args[2]) }
    exit(0)
}

if args.count > 1 {
    let usage = """
    Claude Personas \(appVersion)
    Usage: ClaudePersonas [--list | --check-update | --update-now |
      --selftest-update | --selftest-profiles | --selftest-signin |
      --selftest-launchers | --selftest-version | --selftest-signature |
      --sign-update FILE | --verify-update FILE SIGNATURE |
      --export-iconset DIRECTORY | --export-profile-icon FILE | --unregister-login]
    """
    if args.count == 2 && ["--help", "-h", "--version"].contains(args[1]) {
        print(args[1] == "--version" ? appVersion : usage)
        exit(0)
    }
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(2)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
