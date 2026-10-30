//
//  MCPHost.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 29/10/26.
//

import Foundation
import MCP
import Network

actor MCPHost {
    private var listener: NWListener?
    private var sessions: [ObjectIdentifier: (NWConnection, Server)] = [:]

    func start() throws {
        guard listener == nil else { return }
        let newListener = try NWListener(using: .tcp)
        newListener.service = NWListener.Service(name: "Tether", type: "_mcp._tcp")
        newListener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }
        newListener.start(queue: .global())
        newListener.stateUpdateHandler = { print("listener state:", $0) }
        listener = newListener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (connection, _) in sessions.values { connection.cancel() }
        sessions.removeAll()
    }

    private func accept(_ connection: NWConnection) async {
        let server = Server(
            name: "Tether",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        await registerTools(on: server)
        do {
//            try await server.start(transport: NetworkTransport(connection: connection))
            try await server.start(transport: NetworkTransport(connection: connection, heartbeatConfig: .disabled))
            sessions[ObjectIdentifier(connection)] = (connection, server)
        } catch {
            connection.cancel()
        }
    }

//    private func registerTools(on server: Server) async {
//        await server.withMethodHandler(CallTool.self) { params in
//            guard params.name == "ping" else {
//                let message = "Unknown tool: \(params.name)"
//                return CallTool.Result(
//                    content: [.text(text: message, annotations: nil, _meta: nil)],
//                    isError: true
//                )
//            }
//            return CallTool.Result(
//                content: [.text(text: "pong", annotations: nil, _meta: nil)],
//                isError: false
//            )
//        }
//    }

    private func registerTools(on server: Server) async {
        await server.withMethodHandler(ListTools.self) { _ in
            print("ListTools called")
            let ping = Tool(
                name: "ping",
                description: "Health check. Returns pong.",
                inputSchema: .object(["type": .string("object"), "properties": .object([:])])
            )
            return ListTools.Result(tools: [ping])
        }

        await server.withMethodHandler(CallTool.self) { params in
            print("CallTool called:", params.name)
            guard params.name == "ping" else {
                let message = "Unknown tool: \(params.name)"
                return CallTool.Result(
                    content: [.text(text: message, annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            return CallTool.Result(
                content: [.text(text: "pong", annotations: nil, _meta: nil)],
                isError: false
            )
        }
    }
}
