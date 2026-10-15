// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum UpdateSignature {
    static func sign(_ data: Data, keyBase64: String) throws -> String {
        guard let raw = Data(base64Encoded: keyBase64.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw UpdateError.invalid }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: raw).signature(for: data).base64EncodedString()
    }

    static func verify(_ data: Data, signatureBase64: String, publicKeyBase64: String = updatePublicKey) -> Bool {
        guard let sig = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
              let raw = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else { return false }
        return key.isValidSignature(sig, for: data)
    }
}
