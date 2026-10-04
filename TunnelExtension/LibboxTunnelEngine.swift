import Foundation
import Libbox
import SwiftShieldCore

final class LibboxTunnelEngine {
    private weak var provider: PacketTunnelProvider?
    private var platformInterface: LibboxPlatformInterface?
    private var commandServer: LibboxCommandServer?
    private var configuration: String?

    init(provider: PacketTunnelProvider) {
        self.provider = provider
    }

    func start(profile: TunnelProfile, settings: TunnelSettings) throws {
        let configuration = try SingBoxConfigurationBuilder().makeConfiguration(
            for: profile,
            settings: settings
        )
        try setupLibbox()
        try validate(configuration)

        guard let provider else {
            throw TunnelExtensionError.service("Packet Tunnel Provider уже недоступен.")
        }
        let platformInterface = LibboxPlatformInterface(provider: provider)
        var creationError: NSError?
        guard let commandServer = LibboxNewCommandServer(
            platformInterface,
            platformInterface,
            &creationError
        ) else {
            throw TunnelExtensionError.commandServer(
                creationError?.localizedDescription ?? "неизвестная ошибка"
            )
        }

        self.configuration = configuration
        self.platformInterface = platformInterface
        self.commandServer = commandServer

        do {
            try commandServer.start()
            try commandServer.startOrReloadService(
                configuration,
                options: LibboxOverrideOptions()
            )
        } catch {
            shutdown()
            throw TunnelExtensionError.service(error.localizedDescription)
        }
    }

    func reloadService() throws {
        guard let commandServer, let configuration else { return }
        do {
            try commandServer.startOrReloadService(
                configuration,
                options: LibboxOverrideOptions()
            )
        } catch {
            throw TunnelExtensionError.service(error.localizedDescription)
        }
    }

    func stopService() {
        do {
            try commandServer?.closeService()
        } catch {
            commandServer?.writeMessage(2, message: "stop service: \(error.localizedDescription)")
        }
        platformInterface?.reset()
    }

    func shutdown() {
        stopService()
        commandServer?.close()
        commandServer = nil
        platformInterface = nil
        configuration = nil
    }

    private func setupLibbox() throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) else {
            throw TunnelExtensionError.missingSharedContainer
        }

        let workingURL = containerURL.appendingPathComponent("Libbox", isDirectory: true)
        let tempURL = workingURL.appendingPathComponent("Temp", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: tempURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw TunnelExtensionError.libboxSetup(error.localizedDescription)
        }

        let options = LibboxSetupOptions()
        options.basePath = containerURL.path
        options.workingPath = workingURL.path
        options.tempPath = tempURL.path
        options.logMaxLines = 2_000
        options.debug = _isDebugAssertConfiguration()
        options.crashReportSource = "SwiftShieldTunnel"
        options.appVersion = bundleValue("CFBundleVersion", fallback: "1")
        options.appMarketingVersion = bundleValue("CFBundleShortVersionString", fallback: "0.1.0")
        options.oomKillerEnabled = true
        options.platformMetadata = "{\"networkExtension\":{\"includeAllNetworks\":true}}"

        var setupError: NSError?
        let success = LibboxSetup(options, &setupError)
        guard success, setupError == nil else {
            throw TunnelExtensionError.libboxSetup(
                setupError?.localizedDescription ?? "неизвестная ошибка"
            )
        }
    }

    private func validate(_ configuration: String) throws {
        var validationError: NSError?
        let valid = LibboxCheckConfig(configuration, &validationError)
        guard valid, validationError == nil else {
            throw TunnelExtensionError.invalidConfiguration(
                validationError?.localizedDescription ?? "неизвестная ошибка"
            )
        }
    }

    private func bundleValue(_ key: String, fallback: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? fallback
    }
}
