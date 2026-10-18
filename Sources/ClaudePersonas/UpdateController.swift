// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import AppKit
import Combine
import Sparkle

/// One owner for the update lifecycle. Never initialize Sparkle for package-managed copies.
@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateController()
    static let homebrewCommand = "brew update && brew upgrade --cask macfika/claude-personas/claude-personas"

    @Published private(set) var channel = InstallationChannel.detect()
    @Published private(set) var automaticChecksEnabled = false
    @Published private(set) var canCheckForUpdates = false
    private var controller: SPUStandardUpdaterController?
    private var checkObservation: NSKeyValueObservation?
    private var preferenceObservation: NSKeyValueObservation?
    private var incomingVersion: String?

    func start() {
        channel = InstallationChannel.detect()
        guard channel.allowsSelfUpdates, !isDemo, !isCLI, controller == nil else { return }
        let info = Bundle.main.infoDictionary ?? [:]
        guard let feed = info["SUFeedURL"] as? String, let url = URL(string: feed),
              url.scheme == "https", let key = info["SUPublicEDKey"] as? String,
              Data(base64Encoded: key)?.count == 32 else {
            report(NSError(domain: "ClaudePersonas.Updater", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Missing update feed or public signing key."]))
            return
        }
        let defaults = UserDefaults.standard
        // Preserve a previous explicit opt-out once; Sparkle owns the preference afterwards.
        if defaults.object(forKey: "SUEnableAutomaticChecks") == nil,
           let previous = defaults.object(forKey: "autoUpdate") as? Bool {
            defaults.set(previous, forKey: "SUEnableAutomaticChecks")
        }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        checkObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let enabled = change.newValue ?? false
            Task { @MainActor [weak self] in self?.canCheckForUpdates = enabled }
        }
        preferenceObservation = controller.updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let enabled = change.newValue ?? false
            Task { @MainActor [weak self] in self?.automaticChecksEnabled = enabled }
        }
        controller.startUpdater()
        automaticChecksEnabled = controller.updater.automaticallyChecksForUpdates
        canCheckForUpdates = controller.updater.canCheckForUpdates
    }

    func toggleAutomaticChecks() {
        guard permitSelfUpdate() else { return }
        start()
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates.toggle()
        automaticChecksEnabled = updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        guard permitSelfUpdate() else { return }
        start()
        guard let controller, controller.updater.canCheckForUpdates else { return }
        PanelController.shared.close()
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    func showHomebrewInstructions() {
        let (choice, _) = Dialogs.alert(L("Updates are managed by Homebrew."),
                                        L("Run %@ in Terminal to update this installation.", Self.homebrewCommand),
                                        buttons: [L("Copy Command"), L("Cancel")])
        if choice == 0 {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.homebrewCommand, forType: .string)
        }
    }

    private func permitSelfUpdate() -> Bool {
        channel = InstallationChannel.detect()
        guard !isDemo, !isCLI else { return false }
        if channel.isHomebrew { showHomebrewInstructions(); return false }
        return channel.allowsSelfUpdates
    }

    // Recheck at both boundaries in case Homebrew takes ownership after app launch.
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        try requireManualInstallation()
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        try requireManualInstallation()
        incomingVersion = updateItem.displayVersionString
    }

    private func requireManualInstallation() throws {
        channel = InstallationChannel.detect()
        guard channel.allowsSelfUpdates, !isDemo, !isCLI else {
            throw NSError(domain: "ClaudePersonas.UpdateChannel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: L("Updates are managed by Homebrew.")])
        }
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        // Respect Quit Profiles with Claude Personas without quitting accounts during updater relaunch.
        Updater.relaunching = true
        UserDefaults.standard.set(incomingVersion ?? appVersion, forKey: "updatedTo")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        // Being current or cancelling installation is not an update failure.
        let failure = error as NSError
        if failure.domain == SUSparkleErrorDomain,
           [SUError.noUpdateError.rawValue, SUError.installationCanceledError.rawValue].contains(OSStatus(failure.code)) { return }
        report(error)
    }

    private func report(_ error: Error) {
        Log.write("Sparkle update error: \(error.localizedDescription)")
        Engine.shared.show(localizedNotice: { L("Unable to check for updates: %@", error.localizedDescription) })
    }
}
