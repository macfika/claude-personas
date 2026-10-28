// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import Foundation

// A launch request is not a successful recovery. Confirm the matching profile process survives
// several polls, and retry failed/short-lived launches a bounded number of times.
struct UpdateRecovery {
    static func profilesToRecover(_ profiles: [Profile], due: Set<UUID>) -> [Profile] {
        profiles.filter { due.contains($0.id) }
    }

    struct Attempt {
        var count = 0
        var requestedAt: Date?
        var pid: Int32?
        var seenAt: Date?
    }
    struct Actions {
        var launch: Set<UUID> = []
        var confirmed: Set<UUID> = []
        var failed: Set<UUID> = []
    }
    private(set) var attempts: [UUID: Attempt] = [:]

    mutating func enqueue(_ ids: Set<UUID>) {
        for id in ids where attempts[id] == nil { attempts[id] = Attempt() }
    }
    mutating func cancel(_ id: UUID) { attempts[id] = nil }

    mutating func poll(running: [UUID: Int32], now: Date) -> Actions {
        var result = Actions()
        for id in Array(attempts.keys) {
            guard var attempt = attempts[id] else { continue }
            if let pid = running[id] {
                if attempt.pid != pid {
                    attempt.pid = pid
                    attempt.seenAt = now
                }
                if let seen = attempt.seenAt, now.timeIntervalSince(seen) >= 6 {
                    result.confirmed.insert(id)
                    attempts[id] = nil
                    continue
                }
            } else {
                attempt.pid = nil
                attempt.seenAt = nil
                let due = attempt.requestedAt.map { now.timeIntervalSince($0) >= 15 } ?? true
                if due {
                    if attempt.count >= 3 {
                        result.failed.insert(id)
                        attempts[id] = nil
                        continue
                    }
                    attempt.count += 1
                    attempt.requestedAt = now
                    result.launch.insert(id)
                }
            }
            attempts[id] = attempt
        }
        return result
    }
}
