//
//  main.swift
//  tether-cli
//
//  Created by Dheeraj Singh Rathore on 28/10/26.
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

    func run() {
        let browser = NWBrowser(for: .bonjour(type: "_mcp._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, self.connection == nil, let result = results.first else { return }
            self.connect(to: result.endpoint)
        }
        browser.start(queue: queue)
        self.browser = browser
        queue.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.connection == nil {
                log("Tether app not found. Is it running with the server enabled?")
                exit(1)
            }
        }
    }

    private func connect(to endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.pumpStdin()
                self?.pumpConnection()
            case .failed(let error):
                log("connection failed: \(error)")
                exit(1)
            case .cancelled:
                exit(0)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

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
