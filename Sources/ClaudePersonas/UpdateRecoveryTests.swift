// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import Foundation

enum UpdateRecoveryTests {
    static func run() -> Bool {
        var ok = true
        func check(_ name: String, _ value: Bool) {
            print(value ? "PASS" : "FAIL", name)
            ok = ok && value
        }
        let a = UUID(), other = UUID()
        let t = Date(timeIntervalSince1970: 1_000_000)
        var recovery = UpdateRecovery()
        recovery.enqueue([a])
        let first = recovery.poll(running: [:], now: t)
        check("launch request does not announce recovery", first.launch == [a] && first.confirmed.isEmpty)
        let wrong = recovery.poll(running: [other: 42], now: t.addingTimeInterval(3))
        check("default process cannot confirm profile recovery", wrong.confirmed.isEmpty)
        let seen = recovery.poll(running: [a: 43], now: t.addingTimeInterval(6))
        check("brief process appearance does not announce recovery", seen.confirmed.isEmpty)
        let gone = recovery.poll(running: [:], now: t.addingTimeInterval(15))
        check("short lived launch retries", gone.launch == [a] && gone.confirmed.isEmpty)
        recovery.enqueue([a])
        check("repeated candidates do not reset attempt budget", recovery.attempts[a]?.count == 2)
        _ = recovery.poll(running: [:], now: t.addingTimeInterval(30))
        let failed = recovery.poll(running: [:], now: t.addingTimeInterval(45))
        check("three failed requests report failure and stop", failed.failed == [a] && recovery.attempts.isEmpty)
        check("failed recovery does not retry forever", recovery.poll(running: [:], now: t.addingTimeInterval(60)).launch.isEmpty)
        recovery.enqueue([a])
        _ = recovery.poll(running: [:], now: t)
        _ = recovery.poll(running: [a: 51], now: t.addingTimeInterval(3))
        let changed = recovery.poll(running: [a: 52], now: t.addingTimeInterval(9))
        check("PID replacement restarts stability check", changed.confirmed.isEmpty)
        let stable = recovery.poll(running: [a: 52], now: t.addingTimeInterval(15))
        check("matching stable process confirms recovery", stable.confirmed == [a] && recovery.attempts.isEmpty)
        recovery.enqueue([a]); recovery.cancel(a)
        check("user cancellation prevents recovery", recovery.poll(running: [:], now: t).launch.isEmpty)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let config = root.appendingPathComponent("config.json")
            func write(_ update: Bool, _ quit: Date) throws {
                let data = try JSONSerialization.data(withJSONObject: ["lastQuitCleanup": [
                    "for_update": update, "quit_epoch_ms": quit.timeIntervalSince1970 * 1000]])
                try data.write(to: config)
            }
            try write(true, t)
            check("fresh update cleanup accepted", UpdateWatch.quitForUpdate(config: config, launchedAt: t.addingTimeInterval(-100), stoppedAt: t.addingTimeInterval(2)) == true)
            check("previous process cleanup rejected", UpdateWatch.quitForUpdate(config: config, launchedAt: t.addingTimeInterval(1), stoppedAt: t.addingTimeInterval(2)) == nil)
            check("stale cleanup rejected", UpdateWatch.quitForUpdate(config: config, launchedAt: t.addingTimeInterval(-100), stoppedAt: t.addingTimeInterval(60)) == nil)
            check("unknown process launch rejected", UpdateWatch.quitForUpdate(config: config, launchedAt: nil, stoppedAt: t) == nil)
            try write(false, t)
            check("manual quit rejected", UpdateWatch.quitForUpdate(config: config, launchedAt: t.addingTimeInterval(-100), stoppedAt: t) == false)
            try Data("invalid".utf8).write(to: config)
            check("invalid cleanup ignored", UpdateWatch.quitForUpdate(config: config, launchedAt: t.addingTimeInterval(-100), stoppedAt: t) == nil)
        } catch { check("update exit fixtures", false) }
        let stopped = [a: t]
        check("update recovery allows installer handoff", UpdateWatch.due(quitAt: stopped, updatedAt: .distantPast, relaunched: false, now: t.addingTimeInterval(14), updateExits: [a]).isEmpty)
        check("explicit update exit works without version change", UpdateWatch.due(quitAt: stopped, updatedAt: .distantPast, relaunched: false, now: t.addingTimeInterval(15), updateExits: [a]) == [a])
        check("ordinary quit without update is not recovered", UpdateWatch.due(quitAt: stopped, updatedAt: .distantPast, relaunched: false, now: t.addingTimeInterval(20)).isEmpty)
        return ok
    }
}
