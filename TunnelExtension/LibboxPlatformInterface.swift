import Foundation
import Libbox
import Network
import NetworkExtension
import os

final class LibboxPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private static let logger = Logger(subsystem: "com.swiftshield.app", category: "Tunnel")

    private weak var provider: PacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var pathMonitor: NWPathMonitor?
    private var lastNetworkPath: String?

    init(provider: PacketTunnelProvider) {
        self.provider = provider
    }

    func openTun(
        _ options: (any LibboxTunOptionsProtocol)?,
        ret0_: UnsafeMutablePointer<Int32>?
    ) throws {
        try runBlocking { [weak self] in
            guard let self else { return }
            try await self.openTun(options, result: ret0_)
        }
    }

    private func openTun(
        _ options: (any LibboxTunOptionsProtocol)?,
        result: UnsafeMutablePointer<Int32>?
    ) async throws {
        guard let options else { throw TunnelExtensionError.missingTunnelOptions }
        guard let result else { throw TunnelExtensionError.missingTunnelFileDescriptor }
        guard let provider else {
            throw TunnelExtensionError.service("Packet Tunnel Provider уже недоступен.")
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())
            try configureDNS(options, settings: settings)
            configureIPv4(options, settings: settings)
            configureIPv6(options, settings: settings)
        }
        configureProxy(options, settings: settings)

        networkSettings = settings
        try await provider.setTunnelNetworkSettings(settings)

        if let descriptor = provider.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            result.pointee = descriptor
            return
        }
        if let descriptor = provider.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? NSNumber {
            result.pointee = descriptor.int32Value
            return
        }
        let descriptor = LibboxGetTunnelFileDescriptor()
        guard descriptor >= 0 else {
            throw TunnelExtensionError.missingTunnelFileDescriptor
        }
        result.pointee = descriptor
    }

    private func configureDNS(
        _ options: any LibboxTunOptionsProtocol,
        settings: NEPacketTunnelNetworkSettings
    ) throws {
        guard options.getDNSMode()?.value != LibboxDNSModeDisabled else { return }
        let iterator = try options.getDNSServerAddress()
        var servers: [String] = []
        while iterator.hasNext() {
            servers.append(iterator.next())
        }
        guard !servers.isEmpty else { return }
        let dns = NEDNSSettings(servers: servers)
        dns.matchDomains = [""]
        dns.matchDomainsNoSearch = true
        settings.dnsSettings = dns
    }

    private func configureIPv4(
        _ options: any LibboxTunOptionsProtocol,
        settings: NEPacketTunnelNetworkSettings
    ) {
        var addresses: [String] = []
        var masks: [String] = []
        if let iterator = options.getInet4Address() {
            while iterator.hasNext() {
                guard let prefix = iterator.next() else { continue }
                addresses.append(prefix.address())
                masks.append(prefix.mask())
            }
        }
        guard !addresses.isEmpty else { return }

        let ipv4 = NEIPv4Settings(addresses: addresses, subnetMasks: masks)
        var includedRoutes = ipv4Routes(options.getInet4RouteAddress())
        if includedRoutes.isEmpty {
            includedRoutes = [NEIPv4Route.default()]
        }
        ipv4.includedRoutes = includedRoutes
        ipv4.excludedRoutes = ipv4Routes(options.getInet4RouteExcludeAddress())
        settings.ipv4Settings = ipv4
    }

    private func configureIPv6(
        _ options: any LibboxTunOptionsProtocol,
        settings: NEPacketTunnelNetworkSettings
    ) {
        var addresses: [String] = []
        var prefixLengths: [NSNumber] = []
        if let iterator = options.getInet6Address() {
            while iterator.hasNext() {
                guard let prefix = iterator.next() else { continue }
                addresses.append(prefix.address())
                prefixLengths.append(NSNumber(value: prefix.prefix()))
            }
        }
        guard !addresses.isEmpty else { return }

        let ipv6 = NEIPv6Settings(addresses: addresses, networkPrefixLengths: prefixLengths)
        var includedRoutes = ipv6Routes(options.getInet6RouteAddress())
        if includedRoutes.isEmpty {
            includedRoutes = [NEIPv6Route.default()]
        }
        ipv6.includedRoutes = includedRoutes
        ipv6.excludedRoutes = ipv6Routes(options.getInet6RouteExcludeAddress())
        settings.ipv6Settings = ipv6
    }

    private func configureProxy(
        _ options: any LibboxTunOptionsProtocol,
        settings: NEPacketTunnelNetworkSettings
    ) {
        guard options.isHTTPProxyEnabled() else { return }
        let proxy = NEProxySettings()
        let server = NEProxyServer(
            address: options.getHTTPProxyServer(),
            port: Int(options.getHTTPProxyServerPort())
        )
        proxy.httpEnabled = true
        proxy.httpsEnabled = true
        proxy.httpServer = server
        proxy.httpsServer = server
        proxy.exceptionList = strings(options.getHTTPProxyBypassDomain())
        proxy.matchDomains = strings(options.getHTTPProxyMatchDomain())
        settings.proxySettings = proxy
    }

    private func ipv4Routes(
        _ iterator: (any LibboxRoutePrefixIteratorProtocol)?
    ) -> [NEIPv4Route] {
        guard let iterator else { return [] }
        var routes: [NEIPv4Route] = []
        while iterator.hasNext() {
            guard let prefix = iterator.next() else { continue }
            routes.append(
                NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask())
            )
        }
        return routes
    }

    private func ipv6Routes(
        _ iterator: (any LibboxRoutePrefixIteratorProtocol)?
    ) -> [NEIPv6Route] {
        guard let iterator else { return [] }
        var routes: [NEIPv6Route] = []
        while iterator.hasNext() {
            guard let prefix = iterator.next() else { continue }
            routes.append(
                NEIPv6Route(
                    destinationAddress: prefix.address(),
                    networkPrefixLength: NSNumber(value: prefix.prefix())
                )
            )
        }
        return routes
    }

    private func strings(_ iterator: (any LibboxStringIteratorProtocol)?) -> [String] {
        guard let iterator else { return [] }
        var values: [String] = []
        while iterator.hasNext() {
            values.append(iterator.next())
        }
        return values
    }

    func usePlatformAutoDetectControl() -> Bool { false }

    func autoDetectControl(_ fd: Int32) throws {}

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw unsupported("Поиск владельца соединения")
    }

    func useProcFS() -> Bool { false }

    func startDefaultInterfaceMonitor(
        _ listener: (any LibboxInterfaceUpdateListenerProtocol)?
    ) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        let firstUpdate = DispatchSemaphore(value: 0)
        var isFirstUpdate = true
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateDefaultInterface(listener, path: path)
            if isFirstUpdate {
                isFirstUpdate = false
                firstUpdate.signal()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.swiftshield.path-monitor"))
        guard firstUpdate.wait(timeout: .now() + 5) == .success else {
            monitor.cancel()
            pathMonitor = nil
            throw TunnelExtensionError.service("Не удалось определить активный сетевой интерфейс.")
        }
    }

    func closeDefaultInterfaceMonitor(
        _ listener: (any LibboxInterfaceUpdateListenerProtocol)?
    ) throws {
        pathMonitor?.cancel()
        pathMonitor = nil
        lastNetworkPath = nil
    }

    private func updateDefaultInterface(
        _ listener: any LibboxInterfaceUpdateListenerProtocol,
        path: Network.NWPath
    ) {
        let description = describe(path)
        listener.updateNetworkPath(description)
        guard description != lastNetworkPath else { return }
        lastNetworkPath = description

        guard path.status == .satisfied, let interface = path.availableInterfaces.first else {
            listener.updateDefaultInterface(
                "",
                interfaceIndex: -1,
                isExpensive: false,
                isConstrained: false
            )
            return
        }
        listener.updateDefaultInterface(
            interface.name,
            interfaceIndex: Int32(interface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    private func describe(_ path: Network.NWPath) -> String {
        let status: String
        switch path.status {
        case .satisfied: status = "satisfied"
        case .unsatisfied: status = "unsatisfied"
        case .requiresConnection: status = "requiresConnection"
        @unknown default: status = "unknown"
        }
        let interfaces = path.availableInterfaces
            .map { "\($0.name)#\($0.index)" }
            .joined(separator: ",")
        return "\(status) interfaces=\(interfaces) expensive=\(path.isExpensive) constrained=\(path.isConstrained)"
    }

    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        guard let pathMonitor else {
            throw TunnelExtensionError.service("Монитор сетевых интерфейсов не запущен.")
        }
        let interfaces = pathMonitor.currentPath.availableInterfaces.map { item in
            let interface = LibboxNetworkInterface()
            interface.name = item.name
            interface.index = Int32(item.index)
            switch item.type {
            case .wifi: interface.type = LibboxInterfaceTypeWIFI
            case .cellular: interface.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: interface.type = LibboxInterfaceTypeEthernet
            default: interface.type = LibboxInterfaceTypeOther
            }
            return interface
        }
        return NetworkInterfaceIterator(interfaces)
    }

    func underNetworkExtension() -> Bool { true }

    func includeAllNetworks() -> Bool { true }

    func clearDNSCache() {
        guard let provider, let networkSettings else { return }
        do {
            try runBlocking {
                provider.reasserting = true
                defer { provider.reasserting = false }
                try await provider.setTunnelNetworkSettings(nil)
                try await provider.setTunnelNetworkSettings(networkSettings)
            }
        } catch {
            Self.logger.error("DNS reset failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func readWIFIState() -> LibboxWIFIState? { nil }

    func connectSSHAgent(_ ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw unsupported("SSH agent")
    }

    func serviceStop() throws {
        provider?.stopService()
    }

    func serviceReload() throws {
        try provider?.reloadService()
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        guard let proxy = networkSettings?.proxySettings, proxy.httpServer != nil else {
            return status
        }
        status.available = true
        status.enabled = proxy.httpEnabled
        return status
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {
        guard let provider,
              let networkSettings,
              let proxy = networkSettings.proxySettings,
              proxy.httpServer != nil else { return }
        proxy.httpEnabled = enabled
        proxy.httpsEnabled = enabled
        networkSettings.proxySettings = proxy
        try runBlocking {
            try await provider.setTunnelNetworkSettings(networkSettings)
        }
    }

    func triggerNativeCrash() throws {
        throw unsupported("Native crash")
    }

    func writeDebugMessage(_ message: String?) {
        guard let message else { return }
        Self.logger.debug("\(message, privacy: .public)")
    }

    func send(_ notification: LibboxNotification?) throws {}

    func cancelNotification(_ identifier: String?, typeID: Int32) throws {}

    func startNeighborMonitor(
        _ listener: (any LibboxNeighborUpdateListenerProtocol)?
    ) throws {}

    func closeNeighborMonitor(
        _ listener: (any LibboxNeighborUpdateListenerProtocol)?
    ) throws {}

    func registerMyInterface(_ name: String?) {}

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }

    func usePlatformShell() -> Bool { false }

    func checkPlatformShell() throws {
        throw unsupported("Platform shell")
    }

    func openShellSession(
        _ user: LibboxPlatformUser?,
        command: String?,
        environ: (any LibboxStringIteratorProtocol)?,
        term: String?,
        rows: Int32,
        cols: Int32
    ) throws -> any LibboxShellSessionProtocol {
        throw unsupported("Platform shell")
    }

    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String {
        error?.pointee = unsupported("SSH host key")
        return ""
    }

    func lookupSFTPServer(_ error: NSErrorPointer) -> String {
        error?.pointee = unsupported("SFTP server")
        return ""
    }

    func tailscaleHostname() -> String { "SwiftShield iPhone" }

    func usePlatformBridge() -> Bool { false }

    func createBridge(_ options: LibboxBridgeOptions?) throws -> any LibboxBridgeSessionProtocol {
        throw unsupported("Bridge")
    }

    func usePlatformAutoRedirect() -> Bool { false }

    func createAutoRedirect(
        _ options: Data?,
        handler: (any LibboxAutoRedirectHandlerProtocol)?
    ) throws -> any LibboxAutoRedirectSessionProtocol {
        throw unsupported("Auto redirect")
    }

    func lookupUser(_ username: String?) throws -> LibboxPlatformUser {
        throw unsupported("User lookup")
    }

    func reset() {
        networkSettings = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        lastNetworkPath = nil
    }

    private func unsupported(_ feature: String) -> NSError {
        NSError(
            domain: "SwiftShield.LibboxPlatform",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "\(feature) не поддерживается на iOS."]
        )
    }
}

private final class NetworkInterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private let interfaces: [LibboxNetworkInterface]
    private var index = 0
    private var current: LibboxNetworkInterface?

    init(_ interfaces: [LibboxNetworkInterface]) {
        self.interfaces = interfaces
    }

    func hasNext() -> Bool {
        guard index < interfaces.count else {
            current = nil
            return false
        }
        current = interfaces[index]
        index += 1
        return true
    }

    func next() -> LibboxNetworkInterface? {
        current
    }
}
