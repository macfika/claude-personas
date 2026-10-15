// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Updater {
    static let latestURL = URL(string: "https://api.github.com/repos/macfika/claude-personas/releases/latest")!
    @MainActor static var relaunching = false
    @MainActor static var busy = false

    struct Release { let version: String; let zip: URL; let signature: URL }

    static var currentVersion: String { ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_FAKE_VERSION"] ?? appVersion }

    @MainActor static func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { checkIfDue(force: true) }
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            MainActor.assumeIsolated { checkIfDue(force: false) }
        }
    }

    @MainActor static func checkIfDue(force: Bool) {
        let d = UserDefaults.standard
        guard Engine.shared.isOn(.autoUpdate), !busy else { return }
        if !force, let last = d.object(forKey: "lastUpdateCheck") as? Date, -last.timeIntervalSinceNow < 86_400 { return }
        d.set(Date(), forKey: "lastUpdateCheck")
        let target = Bundle.main.bundleURL
        guard target.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else { return }
        busy = true
        Task.detached {
            let installed = try? await updateIfNewer(at: target)
            await MainActor.run {
                busy = false
                if let installed { relaunchWhenIdle(version: installed, app: target) }
            }
        }
    }

    // Returns the version it installed, or nil when the app is already up to date.
    static func updateIfNewer(at target: URL) async throws -> String? {
        guard let r = try await latest(), isNewer(r.version, than: currentVersion) else { return nil }
        try await install(r, at: target)
        return r.version
    }

    static func latest() async throws -> Release? {
        var req = URLRequest(url: latestURL, timeoutInterval: 30)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ClaudePersonas/\(appVersion)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]],
              let asset = assets.first(where: { ($0["name"] as? String) == "ClaudePersonas-\(tag.hasPrefix("v") ? String(tag.dropFirst()) : tag).zip" }),
              let name = asset["name"] as? String,
              let sigAsset = assets.first(where: { $0["name"] as? String == name + ".sig" }),
              let url = trusted(asset["browser_download_url"]), let sigURL = trusted(sigAsset["browser_download_url"])
        else { return nil }
        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, zip: url, signature: sigURL)
    }

    static func trusted(_ any: Any?) -> URL? {
        guard let s = any as? String, let url = URL(string: s), url.scheme == "https", url.host == "github.com",
              url.path.hasPrefix("/macfika/claude-personas/releases/download/") else { return nil }
        return url
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    // Downloads the release zip, checks that it holds ClaudePersonas at the advertised version with an intact
    // signature, then swaps it in place of the running bundle.
    static func install(_ r: Release, at target: URL) async throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("ClaudePersonas-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let (tmp, resp) = try await URLSession.shared.download(from: r.zip)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.download }
        let zip = work.appendingPathComponent("update.zip")
        try fm.moveItem(at: tmp, to: zip)
        // The zip must carry a signature made with the release key; HTTPS alone would trust whoever controls the repo.
        let (sigData, sigResp) = try await URLSession.shared.data(from: r.signature)
        guard (sigResp as? HTTPURLResponse)?.statusCode == 200,
              UpdateSignature.verify(try Data(contentsOf: zip), signatureBase64: String(decoding: sigData, as: UTF8.self))
        else { throw UpdateError.signature }
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
        let app = work.appendingPathComponent("ClaudePersonas.app")
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == "com.macfika.claude-personas",
              info?["CFBundleShortVersionString"] as? String == r.version else { throw UpdateError.invalid }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        _ = try fm.replaceItemAt(target, withItemAt: app)
    }

    static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw UpdateError.command(tool) }
    }

    @MainActor static func relaunchWhenIdle(version: String, app: URL) {
        guard !PanelController.shared.isOpen else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { relaunchWhenIdle(version: version, app: app) }
            return
        }
        UserDefaults.standard.set(version, forKey: "updatedTo")
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", app.path]
        try? sh.run()
        relaunching = true
        NSApp.terminate(nil)
    }
}

// Every Claude instance writes to the same main.log, so new lines since the sign-in started tell when it lands.
// Takes over claude:// links for the length of a sign-in and forwards them to one Claude process.
// ~/Library/Logs/ClaudePersonas.log: link relays and sign-ins, for support. Links are logged without their query.
