// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import Combine
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

@MainActor
final class Engine: ObservableObject {
    static let shared = Engine()

    @Published private(set) var profiles: [Profile]
    @Published private(set) var running: [UUID: NSRunningApplication] = [:]
    @Published private(set) var frontID: UUID?     // profile of the frontmost Claude window
    @Published private var noticeProvider: (@MainActor () -> String)? {
        didSet { recoveryNoticeProfiles = [] }
    }
    private var recoveryNoticeProfiles: Set<UUID> = []
    var notice: String? { noticeProvider?() } // Render again in the currently selected language.

    var onChange: (() -> Void)?
    var onPanelHotKey: (() -> Void)?

    private let defaults = UserDefaults.standard
    private var pending: [UUID: Date] = [:]   // launched, process not seen yet
    private var demoRunning: Set<UUID> = []
    private var claudeVersion = UpdateWatch.installedVersion()
    private var updatedAt: Date?
    private var observedProcesses: [UUID: UpdateWatch.ProcessSnapshot] = [:]
    private var updateExits: Set<UUID> = []
    private var updateRecovery = UpdateRecovery()
    private var quitAt: [UUID: Date] = [:]    // profiles that stopped without ClaudePersonas quitting them
    private var userQuit: Set<UUID> = []
    private var stopLog: [UUID: Date] = [:]   // last unrequested stop per profile, kept after it relaunches
    private var strayHandled: Date?           // the update whose stray default window was already closed
    private var bareHandled: [UUID: Date] = [:]   // profile copies last reopened after a bare start

    private init() {
        if isDemo {
            profiles = ["Personal", "Work", "Client", "Research"].enumerated().map { i, n in
                Profile(name: n, dir: i == 0 ? nil : "/tmp/claude-personas-demo/Claude-\(n)")
            }
            for i in profiles.indices { profiles[i].color = i }
            demoRunning = [profiles[0].id, profiles[1].id]
            frontID = profiles[1].id
            return
        }
        if let data = defaults.data(forKey: "profiles"), let list = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = list
        } else {
            profiles = Seed.profiles()
        }
        for i in profiles.indices where profiles[i].color == nil { profiles[i].color = nextColor() }
        discoverFolders()
    }

    private func nextColor() -> Int {
        let used = Set(profiles.compactMap(\.color))
        return Palette.colors.indices.first { !used.contains($0) } ?? profiles.count % Palette.colors.count
    }

    func boot() {
        save()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { note in
                let launched = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let launchedClaude = name == NSWorkspace.didLaunchApplicationNotification && launched?.bundleIdentifier == claudeBundleID
                MainActor.assumeIsolated {
                    // A bare copy can hand off to the default window and quit before refresh() looks.
                    if launchedClaude, let app = launched, let owner = Engine.shared.runtimeOwner(app), !owner.isDefault,
                       !ProcArgs.of(app.processIdentifier).contains(where: { $0.hasPrefix("--user-data-dir=") }) {
                        Engine.shared.reopenBareCopy(app, of: owner)
                    }
                    Engine.shared.refresh()
                    // Claude makes itself the claude:// handler as it starts; take the links back once it's up.
                    if launchedClaude {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { Engine.shared.holdLinks() }
                    }
                }
            }
        }
        if !isDemo { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Engine.shared.holdLinks() } }
        let afterSelfUpdate = defaults.string(forKey: "updatedTo") != nil
        if let to = defaults.string(forKey: "updatedTo") {
            defaults.removeObject(forKey: "updatedTo")
            if to == appVersion { noticeProvider = { L("Claude Personas updated to %@.", to) } }
        }
        if !isDemo { Updater.start() }
        // Electron instances launched with `open -n` sometimes skip the launch notification; poll as a backstop.
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            MainActor.assumeIsolated { Engine.shared.refresh() }
        }
        refresh()
        // A restart after a self-update keeps whatever is open; it does not reopen startup profiles.
        if !isDemo && !afterSelfUpdate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let e = Engine.shared
                e.profiles.filter { $0.openAtLaunch == true && !e.isRunning($0) }.forEach(e.open)
            }
        }
    }

    // MARK: settings

    func isOn(_ s: Setting) -> Bool {
        if s == .launchAtLogin { return SMAppService.mainApp.status == .enabled }
        if Setting.onByDefault.contains(s) && defaults.object(forKey: s.rawValue) == nil { return true }
        return defaults.bool(forKey: s.rawValue)
    }

    func toggle(_ s: Setting) {
        let on = !isOn(s)
        objectWillChange.send()
        if s == .launchAtLogin {
            do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
            catch { NSSound.beep() }
            return
        }
        defaults.set(on, forKey: s.rawValue)
        if s == .shortcut || s == .profileShortcuts { updateHotKeys() }
        if s == .routeSignIn { on ? holdLinks() : LinkRelay.giveBack() }
        if s == .dockApps { syncLaunchers() }
        onChange?()
    }

    // ⌃⌥⌘M opens the panel; ⌃⌥1 to ⌃⌥9 open or focus the profiles in list order.
    func updateHotKeys() {
        var keys: [HotKey.Binding] = []
        if isOn(.shortcut) {
            keys.append(.init(key: kVK_ANSI_M, mods: cmdKey | optionKey | controlKey) { Engine.shared.onPanelHotKey?() })
        }
        if isOn(.profileShortcuts) {
            for (i, p) in profiles.prefix(9).enumerated() {
                let id = p.id
                keys.append(.init(key: HotKey.digits[i], mods: optionKey | controlKey) {
                    if let p = Engine.shared.profiles.first(where: { $0.id == id }) { Engine.shared.open(p) }
                })
            }
        }
        HotKey.register(keys)
    }

    func shortcutHint(for p: Profile) -> String? {
        guard isOn(.profileShortcuts), let i = profiles.firstIndex(of: p), i < 9 else { return nil }
        return "⌃⌥\(i + 1)"
    }

    func dismissNotice() {
        if signIn != nil { finishSignIn(cancelled: true) }
        noticeProvider = nil
    }

    // MARK: sign-in

    // Claude's Google and SSO sign-in leaves through the browser and comes back as a claude:// link, which
    // macOS hands to the first Claude window it finds. During a sign-in ClaudePersonas takes over claude:// links
    // and passes them to the one process that asked, then gives the links back to Claude.
    // If ClaudePersonas can't take the links, it falls back to closing the other accounts for the duration.
    struct SignIn {
        let target: UUID
        var reopen: [UUID] = []
        var logOffset: UInt64
        var sawBrowser = false
        var routing = false
        let started = Date()
    }
    @Published private(set) var signIn: SignIn?
    private var signInTimer: Timer?
    private var lastClaudePid: pid_t?   // the Claude window used last, for claude:// links outside a sign-in

    // While ClaudePersonas, not Claude, handles claude:// links, Claude signs in through an in-window
    // ASWebAuthenticationSession instead of the browser, so every account signs in in its own window.
    // (Claude: "[Auth] Not the claude:// handler; keeping ASWebAuth".)
    func holdLinks() {
        guard !isDemo, !isCLI, isOn(.routeSignIn) || signIn != nil, !LinkRelay.isOurs() else { return }
        LinkRelay.take { _ in }
    }

    func beginSignIn(_ p: Profile) {
        guard !isDemo, signIn == nil else { return }
        signIn = SignIn(target: p.id, logOffset: SignInLog.size())
        noticeProvider = { L("Getting %@ ready to sign in…", p.name) }
        if !isRunning(p) { open(p) }
        signInTimer?.invalidate()
        signInTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { Engine.shared.checkSignIn() }
        }
        // Claude makes itself the claude:// handler as it starts, so take over only once the target is up.
        func waitForTarget(_ n: Int) {
            let e = Engine.shared
            guard e.signIn?.target == p.id else { return }
            e.refresh()
            if e.isRunning(p) || n > 40 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { Engine.shared.takeOverLinks(for: p) }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { waitForTarget(n + 1) }
        }
        waitForTarget(0)
    }

    private func takeOverLinks(for p: Profile) {
        guard signIn?.target == p.id else { return }
        LinkRelay.take { ok in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let e = Engine.shared
                    guard e.signIn?.target == p.id else { LinkRelay.giveBack(); return }
                    if ok {
                        e.signIn?.routing = true
                        e.noticeProvider = { L("Sign in to %@ now. Claude Personas sends the sign-in back to its window.", p.name) }
                        if let app = e.running[p.id] { app.unhide(); app.activate() }
                    } else {
                        e.closeOthersForSignIn(p)
                    }
                }
            }
        }
    }

    // Fallback: with only the target open, the link can only land there.
    private func closeOthersForSignIn(_ p: Profile) {
        let others = profiles.filter { $0.id != p.id && isRunning($0) }
        signIn?.reopen = others.map(\.id)
        noticeProvider = {
            others.isEmpty ? L("Sign in to %@ in its window.", p.name)
                : L("Sign in to %@ in its window. After sign-in, these profiles will reopen: %@.", p.name, Self.profileNames(others))
        }
        func next(_ rest: [Profile]) {
            guard let first = rest.first else { Engine.shared.open(p); return }
            Engine.shared.quitAndWait(first) { next(Array(rest.dropFirst())) }
        }
        next(others)
    }

    // A claude:// link that reached ClaudePersonas: during a sign-in it goes to the target process,
    // otherwise to Claude as usual.
    func relay(_ link: String) {
        Log.write("link in: \(Log.redact(link)) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-") last=\(lastClaudePid.map(String.init) ?? "-")")
        if let s = signIn, s.routing, let app = running[s.target], LinkRelay.send(link, to: app.processIdentifier) {
            signIn?.sawBrowser = true
            LinkRelay.bringForward(app)
            return
        }
        // Otherwise the Claude window in front, or the one used last.
        let front = NSWorkspace.shared.frontmostApplication
        let pid = front?.bundleIdentifier == claudeBundleID ? front?.processIdentifier : lastClaudePid
        if let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated, LinkRelay.send(link, to: pid) {
            Log.write("link sent to pid \(pid)")
            LinkRelay.bringForward(app)
            return
        }
        if !isOn(.routeSignIn) { LinkRelay.giveBack() }
        if let url = URL(string: link) {
            NSWorkspace.shared.open([url], withApplicationAt: LinkRelay.claudeApp, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func checkSignIn() {
        guard var s = signIn else { return }
        if -s.started.timeIntervalSinceNow > 600 { finishSignIn(cancelled: true); return }
        let (lines, offset) = SignInLog.read(from: s.logOffset)
        s.logOffset = offset
        let (sawBrowser, done) = SignInLog.scan(lines, sawBrowser: s.sawBrowser)
        s.sawBrowser = sawBrowser
        signIn = s
        if done { finishSignIn(cancelled: false) }
    }

    func finishSignIn(cancelled: Bool) {
        guard let s = signIn else { return }
        signInTimer?.invalidate()
        signInTimer = nil
        signIn = nil
        if !isOn(.routeSignIn) { LinkRelay.giveBack() }
        let reopen = profiles.filter { s.reopen.contains($0.id) && !isRunning($0) }
        reopen.forEach(open)
        let target = profiles.first { $0.id == s.target }?.name
        if cancelled { noticeProvider = nil; return }
        noticeProvider = {
            L("Signed in to %@.", target ?? L("the account"))
                + (reopen.isEmpty ? "" : " " + L("Reopened %@.", Self.profileNames(reopen)))
        }
    }
    func show(notice text: String) { noticeProvider = { text } }
    func show(localizedNotice: @escaping @MainActor () -> String) { noticeProvider = localizedNotice }

    private static func profileNames(_ profiles: [Profile]) -> String {
        let formatter = ListFormatter()
        formatter.locale = Localization.shared.locale
        return formatter.string(from: profiles.map(\.name)) ?? profiles.map(\.name).joined(separator: ", ")
    }

    // MARK: running instances

    // Matches each Claude process to a profile through its --user-data-dir argument.
    func refresh() {
        guard !isDemo else { return }
        let now = Date()
        var found: [UUID: NSRunningApplication] = [:]
        var observations: [UUID: UpdateWatch.ProcessSnapshot] = [:]
        for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == claudeBundleID && !app.isTerminated {
            let dir = ProcArgs.of(app.processIdentifier)
                .first { $0.hasPrefix("--user-data-dir=") }
                .map { Folders.canonical(String($0.dropFirst(16))) }
            if !isCLI, dir == nil, let owner = runtimeOwner(app), !owner.isDefault {
                reopenBareCopy(app, of: owner)
                continue
            }
            if let p = profiles.first(where: { $0.dir.map(Folders.canonical) == dir }) {
                found[p.id] = app
                observations[p.id] = UpdateWatch.ProcessSnapshot(app: app, observedAt: now)
                if observedProcesses[p.id]?.pid != app.processIdentifier {
                    Log.write("Observed Claude process for \(p.name), pid \(app.processIdentifier)")
                }
            }
        }
        for id in found.keys { pending[id] = nil }
        pending = pending.filter { $0.value.timeIntervalSinceNow > -15 }

        for id in running.keys where found[id] == nil {
            if userQuit.remove(id) == nil {
                quitAt[id] = now
                stopLog[id] = now
                if let p = profiles.first(where: { $0.id == id }), !p.isDefault {
                    let reason = UpdateWatch.quitForUpdate(config: p.folderURL.appendingPathComponent("config.json"),
                                                          launchedAt: observedProcesses[id]?.launchedAt, stoppedAt: now)
                    Log.write("Claude stopped for \(p.name), pid \(observedProcesses[id]?.pid ?? 0), update exit: \(reason.map(String.init) ?? "unknown")")
                    if reason == true {
                        updateExits.insert(id)
                        Log.write("Claude update exit detected for \(p.name)")
                    } else if reason == false {
                        // A normal quit during a retry must not be undone by recovery.
                        updateRecovery.cancel(id)
                        updateExits.remove(id)
                        quitAt[id] = nil
                    }
                }
            }
        }
        observedProcesses = observations
        for id in found.keys { quitAt[id] = nil; updateExits.remove(id) }
        quitAt = quitAt.filter { now.timeIntervalSince($0.value) < 300 }
        updateExits.formIntersection(Set(quitAt.keys))
        stopLog = stopLog.filter { now.timeIntervalSince($0.value) < 600 }
        if let v = UpdateWatch.installedVersion(), v != claudeVersion {
            claudeVersion = v
            updatedAt = now
        }

        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let front, found.values.contains(where: { $0.processIdentifier == front }) { lastClaudePid = front }
        let newFront = found.first { $0.value.processIdentifier == front }?.key
        if found.mapValues(\.processIdentifier) != running.mapValues(\.processIdentifier) || newFront != frontID {
            running = found
            frontID = newFront
            onChange?()
        }
        if !recoveryNoticeProfiles.isSubset(of: Set(found.keys)) { noticeProvider = nil }
        if !isCLI { reopenAfterUpdate(now: now) }
        alignFolders()   // after `running` is current, so an open profile is never moved
    }

    // The profile whose own copy of Claude (see Runtimes) this process runs from, if any.
    func runtimeOwner(_ app: NSRunningApplication) -> Profile? {
        guard let url = app.bundleURL, let id = Runtimes.owner(of: url) else { return nil }
        return profiles.first { $0.id == id }
    }

    // A profile's copy started without --user-data-dir: Claude's updater relaunching it, or a Dock tile
    // kept from a running copy. It would show the default account in that profile's icon, so close it and
    // open the profile on its own account. Our own launches are pending and skipped.
    func reopenBareCopy(_ app: NSRunningApplication?, of p: Profile) {
        if pending[p.id] != nil { return }
        if let t = bareHandled[p.id], Date().timeIntervalSince(t) < 20 { return }
        bareHandled[p.id] = Date()
        Log.write("\(p.name)'s copy of Claude started without its folder; reopening it on its own account")
        app?.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let e = Engine.shared
            if !e.isRunning(p) { e.open(p) }
        }
    }

    // Claude relaunches itself without --user-data-dir when it installs an update, so profile windows
    // come back on the default account. Reopen each profile that stopped around the update.
    private func reopenAfterUpdate(now: Date) {
        guard isOn(.reopenAfterUpdate) else {
            updateRecovery = UpdateRecovery()
            updateExits = []
            return
        }
        let relaunched = updatedAt.map { date in
            running.values.contains { ($0.launchDate ?? .distantPast) > date.addingTimeInterval(-10) }
        } ?? false
        if let updatedAt { closeStrayDefault(updatedAt: updatedAt) }
        let due = UpdateWatch.due(quitAt: quitAt, updatedAt: updatedAt ?? .distantPast,
                                 relaunched: relaunched, now: now, updateExits: updateExits)
        let eligible = Set(profiles.filter { due.contains($0.id) && !$0.isDefault }.map(\.id))
        updateRecovery.enqueue(eligible)
        for id in eligible { quitAt[id] = nil; updateExits.remove(id) }
        for id in Array(updateRecovery.attempts.keys) where !profiles.contains(where: { $0.id == id }) {
            updateRecovery.cancel(id)
        }
        let actions = updateRecovery.poll(running: running.mapValues(\.processIdentifier), now: now)
        let launching = profiles.filter { actions.launch.contains($0.id) }
        if !launching.isEmpty {
            noticeProvider = { L("Claude exited for an update. Reopening %@…", Self.profileNames(launching)) }
            for p in launching {
                Log.write("Requesting update recovery for \(p.name), attempt \(updateRecovery.attempts[p.id]?.count ?? 0)")
                open(p)
            }
        }
        let confirmed = profiles.filter { actions.confirmed.contains($0.id) }
        if !confirmed.isEmpty {
            noticeProvider = { L("Claude exited for an update. Reopened %@.", Self.profileNames(confirmed)) }
            recoveryNoticeProfiles = Set(confirmed.map(\.id))
            for p in confirmed { Log.write("Update recovery confirmed for \(p.name)") }
        }
        let failed = profiles.filter { actions.failed.contains($0.id) }
        if !failed.isEmpty {
            noticeProvider = { L("Could not reopen %@ after Claude exited for an update. Open it manually to try again.", Self.profileNames(failed)) }
            for p in failed {
                quitAt[p.id] = nil
                updateExits.remove(p.id)
                Log.write("Update recovery failed for \(p.name) after 3 attempts")
            }
        }
        if !launching.isEmpty || !confirmed.isEmpty || !failed.isEmpty { onChange?() }
    }

    func isRunning(_ p: Profile) -> Bool { running[p.id] != nil || demoRunning.contains(p.id) }
    func isStarting(_ p: Profile) -> Bool { pending[p.id] != nil && running[p.id] == nil }
    var runningCount: Int { running.count + demoRunning.count }

    // MARK: actions

    func open(_ p: Profile) {
        if isDemo {
            demoRunning.insert(p.id); frontID = p.id; objectWillChange.send(); onChange?(); return
        }
        if let app = running[p.id] {
            LinkRelay.bringForward(app)
            return
        }
        if let dir = p.dir { try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true) }
        let anyClaude = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == claudeBundleID && !$0.isTerminated }
        // With profile apps on, the profile runs in its own named copy of Claude (see Runtimes).
        let app = (isOn(.dockApps) && !isDemo ? Runtimes.ensure(p, from: realClaudeApp()) : nil) ?? realClaudeApp()
        let args = Launch.openArgs(app: app.path, dir: p.dir, anyClaudeRunning: anyClaude)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = args
        task.terminationHandler = { process in
            if process.terminationStatus != 0 {
                Log.write("Launch request failed for \(p.name), open status \(process.terminationStatus)")
            }
        }
        do { try task.run() } catch {
            Log.write("Could not send launch request for \(p.name)")
            NSSound.beep(); return
        }
        objectWillChange.send()
        pending[p.id] = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { Engine.shared.refresh() }
    }

    // Claude's relaunch after an update opens the default account even when it was not open before.
    // Close that window, but only when the default did not stop around the update itself.
    private func closeStrayDefault(updatedAt: Date) {
        guard strayHandled != updatedAt, let d = profiles.first(where: \.isDefault), let app = running[d.id],
              pending[d.id] == nil else { return }
        let others = stopLog.filter { $0.key != d.id }.map(\.value)
        guard UpdateWatch.isStrayDefault(defaultLaunch: app.launchDate, defaultStop: stopLog[d.id],
                                         profileStops: others, updatedAt: updatedAt) else { return }
        strayHandled = updatedAt
        userQuit.insert(d.id)
        app.terminate()
    }

    func quit(_ p: Profile) {
        updateRecovery.cancel(p.id)
        updateExits.remove(p.id)
        quitAt[p.id] = nil
        if isDemo {
            demoRunning.remove(p.id); if frontID == p.id { frontID = nil }; objectWillChange.send(); onChange?(); return
        }
        guard let app = running[p.id] else { return }
        userQuit.insert(p.id)
        app.terminate()
    }

    // Opens Terminal running Claude Code signed in as this profile's account.
    func openClaudeCode(_ p: Profile) {
        guard !isDemo else { return }
        var lines = ["#!/bin/zsh"]
        if let dir = p.codeConfigDir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            lines.append("export CLAUDE_CONFIG_DIR=\(shellQuote(dir))")
        }
        lines += ["clear", "echo \(shellQuote("Claude Code as " + p.name))", "cd ~", "claude", "exec $SHELL -l"]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClaudePersonas-\(p.id.uuidString.prefix(8)).command")
        do {
            try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch { NSSound.beep(); return }
        NSWorkspace.shared.open(url)
    }

    func openAll() { profiles.filter { !isRunning($0) }.forEach(open) }
    func quitAll() { profiles.forEach(quit) }

    // MARK: editing

    @discardableResult
    func add(name raw: String) -> Bool {
        guard let p = newProfile(named: raw) else { NSSound.beep(); return false }
        profiles.append(p)
        save()
        return true
    }

    // A profile with a fresh Claude-<name> folder, or nil when the name is empty, taken or its folder exists.
    func newProfile(named raw: String) -> Profile? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let dir = supportDir.appendingPathComponent("Claude-\(slug)").path
        guard !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains), !slug.isEmpty,
              !FileManager.default.fileExists(atPath: dir), (try? FileManager.default.destinationOfSymbolicLink(atPath: dir)) == nil, !profiles.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
              !profiles.contains(where: { $0.dir == dir }) else { return nil }
        return Profile(name: name, dir: dir, color: nextColor())
    }

    func setOpenAtLaunch(_ p: Profile, _ on: Bool) {
        guard let i = profiles.firstIndex(of: p) else { return }
        profiles[i].openAtLaunch = on
        save()
    }

    // Quits a running profile and calls back once its process is gone (or after 15 s).
    func quitAndWait(_ p: Profile, then done: @escaping @Sendable @MainActor () -> Void) {
        guard let app = running[p.id] else { done(); return }
        userQuit.insert(p.id)
        app.terminate()
        func poll(_ n: Int) {
            if app.isTerminated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { MainActor.assumeIsolated { done() } }
                return
            }
            guard n <= 60 else {
                Engine.shared.noticeProvider = { L("Could not close %@. No profile data was changed; close its window and try again.", p.name) }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { poll(n + 1) }
        }
        poll(0)
    }

    // Clones a profile's whole data folder, sign-in and chats included, into a new profile.
    // APFS clones make the copy instant and free until the two folders diverge.
    func duplicate(_ source: Profile, as name: String) {
        guard !isDemo else { return }
        guard let p = newProfile(named: name), let dst = p.dir else { NSSound.beep(); return }
        let wasRunning = isRunning(source)
        noticeProvider = { L("Duplicating %@…", source.name) }
        quitAndWait(source) {
            Task.detached {
                let ok = Duplicate.clone(from: source.folderURL.path, to: dst)
                await MainActor.run {
                    let e = Engine.shared
                    if ok {
                        e.profiles.append(p)
                        e.save()
                        e.noticeProvider = { L("Duplicated %@ as %@. Both are signed in to the same account until you sign one out.", source.name, p.name) }
                    } else {
                        e.noticeProvider = { L("Couldn't duplicate %@. Nothing was changed.", source.name) }
                    }
                    if wasRunning { e.open(source) }
                }
            }
        }
    }

    func copyMCPServers(from source: Profile, to target: Profile, restart: Bool) {
        guard !isDemo else { return }
        do {
            let n = try MCP.copy(from: source, to: target)
            let needsReopen = !restart && isRunning(target)
            noticeProvider = {
                L("Copied MCP servers (%@) from %@ to %@.", String(n), source.name, target.name)
                    + (needsReopen ? " " + L("Reopen %@ to load them.", target.name) : "")
            }
            if restart && isRunning(target) { quitAndWait(target) { Engine.shared.open(target) } }
        } catch {
            noticeProvider = { L("Couldn't copy MCP servers: %@'s config file isn't valid JSON.", target.name) }
        }
    }

    // The folder follows the new name on its own (see alignFolders), once the profile is closed.
    func rename(_ p: Profile, to raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !profiles.contains(where: { $0.id != p.id && $0.name.caseInsensitiveCompare(name) == .orderedSame }),
              let i = profiles.firstIndex(of: p) else { return }
        profiles[i].name = name
        save()
        alignFolders()
    }

    // Takes the profile off the list. Its data folder stays on disk and is not added back.
    func remove(_ p: Profile) {
        guard !p.isDefault, let dir = p.dir else { return }
        defaults.set(Array(Set(ignoredFolders + [Folders.canonical(dir)])), forKey: "ignoredFolders")
        profiles.removeAll { $0.id == p.id }
        save()
    }

    private var ignoredFolders: [String] { defaults.stringArray(forKey: "ignoredFolders") ?? [] }

    // Adds every Claude-* folder in Application Support that no profile uses yet.
    func discoverFolders() {
        guard !isDemo, !isCLI else { return }
        let known = Set(profiles.compactMap(\.dir).map(Folders.canonical) + ignoredFolders)
        let found = Folders.candidates(in: supportDir.path).filter { !known.contains(Folders.canonical($0)) }
        guard !found.isEmpty else { return }
        for dir in found {
            let name = String(URL(fileURLWithPath: dir).lastPathComponent.dropFirst(7))
            profiles.append(Profile(name: name, dir: dir, color: nextColor()))
        }
        save()
    }

    // Renames each closed profile's folder to Claude-<name>. A symlink stays at the old path because
    // Claude writes absolute paths into its data (agent sessions, git config), and old aliases keep working.
    func alignFolders() {
        guard !isDemo, !isCLI, signIn == nil else { return }
        // Read the live processes here rather than trusting `running`, which may not be filled in yet.
        let live = Set(NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == claudeBundleID && !$0.isTerminated }
            .compactMap { ProcArgs.of($0.processIdentifier).first { $0.hasPrefix("--user-data-dir=") } }
            .map { Folders.canonical(String($0.dropFirst(16))) })
        var changed = false
        for i in profiles.indices {
            let p = profiles[i]
            guard let dir = p.dir, !live.contains(Folders.canonical(dir)), !isRunning(p), pending[p.id] == nil,
                  !Folders.inUse(dir),
                  let target = Folders.target(for: p.name, current: dir, in: supportDir.path) else { continue }
            let oldCode = p.codeConfigDir
            if Folders.move(dir, to: target) {
                if p.codeDir == nil, let oldCode, FileManager.default.fileExists(atPath: oldCode) {
                    profiles[i].codeDir = oldCode   // its Keychain sign-in is tied to this path
                }
                profiles[i].dir = target
                changed = true
            }
        }
        if changed { save() }
    }

    func setColor(_ p: Profile, _ c: Int) {
        guard let i = profiles.firstIndex(of: p) else { return }
        profiles[i].color = c
        save()
    }

    // MARK: profile apps

    // Keeps ~/Applications/ClaudePersonas Launchers in step with the list: one app per profile while the
    // setting is on, none while it's off. Apps that move or go away are moved or taken off the Dock too.
    func syncLaunchers() {
        guard !isDemo, !isCLI else { return }
        let result = Launchers.sync(isOn(.dockApps) ? profiles : [], in: Launchers.folder)
        Runtimes.prune(keeping: isOn(.dockApps) ? Set(profiles.map(\.id)) : [])
        // Restyle each profile's own Claude now rather than at its next launch (only the icon if it's open).
        if isOn(.dockApps) {
            let claude = realClaudeApp()
            for p in profiles where Runtimes.exists(p.id) { _ = Runtimes.ensure(p, from: claude) }
        }
        if !result.moved.isEmpty || !result.removed.isEmpty || !result.rewritten.isEmpty {
            Dock.update(moved: result.moved, removed: result.removed, refresh: result.rewritten)
        }
        if !result.failed.isEmpty { noticeProvider = { L("Couldn't write the app for %@.", result.failed.joined(separator: ", ")) } }
    }

    func launcherURL(_ p: Profile) -> URL? {
        guard !isDemo, isOn(.dockApps) else { return nil }
        return Launchers.installed(in: Launchers.folder)[p.id]
    }

    func renameApp(_ p: Profile, to raw: String) {
        guard let i = profiles.firstIndex(of: p) else { return }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return }
        profiles[i].appName = name.isEmpty || name == Profile(name: p.name, dir: p.dir).dockAppName ? nil : name
        save()
    }

    func addToDock(_ p: Profile) {
        if !isOn(.dockApps) { toggle(.dockApps) }
        guard let url = launcherURL(p) else { NSSound.beep(); return }
        if !Dock.add(url) { noticeProvider = { L("Couldn't add %@ to the Dock. Drag it there from Finder instead.", p.dockAppName) } }
    }

    func removeFromDock(_ p: Profile) {
        guard let url = launcherURL(p) else { return }
        Dock.update(moved: [], removed: [url])
    }

    // claude-personas://open?profile=<id>, sent by a profile's app. Opens or brings forward that profile.
    func handleOwnLink(_ link: String) {
        guard let c = URLComponents(string: link), c.host == "open",
              let id = c.queryItems?.first(where: { $0.name == "profile" })?.value.flatMap(UUID.init(uuidString:)),
              let p = profiles.first(where: { $0.id == id }) else { NSSound.beep(); return }
        refresh()   // ClaudePersonas may have just been launched by this link
        open(p)
    }

    func move(_ p: Profile, by delta: Int) {
        guard let i = profiles.firstIndex(of: p) else { return }
        let j = i + delta
        guard profiles.indices.contains(j) else { return }
        profiles.swapAt(i, j)
        save()
    }

    private func save() {
        if !isDemo, !isCLI, let data = try? JSONEncoder().encode(profiles) { defaults.set(data, forKey: "profiles") }
        syncLaunchers()
        updateHotKeys()
        onChange?()
    }
}

// Self-update from GitHub releases. Checks at launch and then once a day, installs in the background,
// and relaunches only while the panel is closed. Claude windows are left alone.
