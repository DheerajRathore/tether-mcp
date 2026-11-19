//
//  main.swift
//  tether-cli
//

import Foundation
import Network

// Relays stdin/stdout <-> the Tether app over local TCP. Logs go to stderr only,
// because stdout belongs to the MCP protocol.
func log(_ message: String) {
    FileHandle.standardError.write(Data("tether-cli: \(message)\n".utf8))
}

final class Relay: @unchecked Sendable {
    private let queue = DispatchQueue(label: "tether.relay")
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var endpoints: [NWEndpoint] = []
    private var isReady = false
    private var launched = false

    private let bundleID = "com.dheeraj.Tether"
    private let launchDelay = 1.5
    private let retryDelay = 0.5
    private let totalTimeout = 15.0

    func run() {
        let browser = NWBrowser(for: .bonjour(type: "_mcp._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.endpoints = results.map(\.endpoint)
            self?.connectIfNeeded()
        }
        browser.start(queue: queue)
        self.browser = browser

        queue.asyncAfter(deadline: .now() + launchDelay) { [weak self] in
            guard let self, !self.isReady, !self.launched else { return }
            self.launchApp()
        }
        queue.asyncAfter(deadline: .now() + totalTimeout) { [weak self] in
            guard let self, !self.isReady else { return }
            log("Tether did not respond in \(Int(self.totalTimeout))s. "
                + "Open Tether and turn on \"Enable MCP server\".")
            exit(1)
        }
    }

    // MARK: - Launch

    private func launchApp() {
        launched = true
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        if let app = bundledAppURL() {
            process.arguments = ["-g", app.path]
        } else {
            process.arguments = ["-g", "-b", bundleID]
        }
        // stdout is the MCP channel, so nothing from the child may reach it.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            log("Tether not found, launching it")
        } catch {
            log("could not launch Tether: \(error)")
        }
    }

    /// tether-cli lives at Tether.app/Contents/MacOS/, so the app is three levels up.
    private func bundledAppURL() -> URL? {
        guard let exe = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return nil }
        let app = exe.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return app.pathExtension == "app" ? app : nil
    }

    // MARK: - Connect

    private func connectIfNeeded() {
        guard connection == nil, !isReady, let endpoint = endpoints.first else { return }
        connect(to: endpoint)
    }

    private func connect(to endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isReady = true
                self.pumpStdin()
                self.pumpConnection()
            case .failed(let error):
                if self.isReady {
                    log("connection failed: \(error)")
                    exit(1)
                }
                self.retry()
            case .waiting:
                // Refused or unreachable before ready: usually a stale Bonjour entry
                // or the app still starting. Drop it and try again.
                if !self.isReady { self.retry() }
            case .cancelled:
                if self.isReady { exit(0) }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func retry() {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        queue.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            self?.connectIfNeeded()
        }
    }

    // MARK: - Relay

    private func pumpStdin() {
        FileHandle.standardInput.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { exit(0) }
            self?.connection?.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func pumpConnection() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, done, error in
            if let data, !data.isEmpty { FileHandle.standardOutput.write(data) }
            if done || error != nil { exit(0) }
            self?.pumpConnection()
        }
    }
}

let relay = Relay()
relay.run()
dispatchMain()
