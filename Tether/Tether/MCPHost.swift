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
    private var notesFolder: URL?

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

    func setNotesFolder(_ url: URL?) { notesFolder = url }

    private func registerTools(on server: Server) async {
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [Self.pingTool(), Self.searchTool()])
        }
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else { return Self.errorResult("Server stopped") }
            return await self.call(name: params.name, arguments: params.arguments)
        }
    }

    private func call(name: String, arguments: [String: Value]?) -> CallTool.Result {
        switch name {
        case "ping": return Self.textResult("pong")
        case "notes_search": return searchNotes(arguments)
        default: return Self.errorResult("Unknown tool: \(name)")
        }
    }

    private func searchNotes(_ arguments: [String: Value]?) -> CallTool.Result {
        guard let folder = notesFolder else {
            return Self.errorResult("Notes folder not connected. Open Tether and choose the Notes folder.")
        }
        let options = NotesDatabase.SearchOptions(
            query: arguments?["query"]?.stringValue,
            folder: arguments?["folder"]?.stringValue,
            since: Self.parseDate(arguments?["since"]?.stringValue),
            limit: min(max(arguments?["limit"]?.intValue ?? 25, 1), 50)
        )
        do {
            let notes = try NotesDatabase.search(folder: folder, options: options)
            let data = try JSONEncoder().encode(notes)
            guard let json = String(data: data, encoding: .utf8) else {
                return Self.errorResult("Could not encode search results.")
            }
            return Self.textResult(json)
        } catch {
            return Self.errorResult(error.localizedDescription)
        }
    }

    private static func parseDate(_ text: String?) -> Date? {
        guard let text else { return nil }
        if let full = ISO8601DateFormatter().date(from: text) { return full }
        let dayOnly = ISO8601DateFormatter()
        dayOnly.formatOptions = [.withFullDate]
        return dayOnly.date(from: text)
    }

    private static func textResult(_ text: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
    }

    private static func errorResult(_ text: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: true)
    }

    private static func pingTool() -> Tool {
        Tool(
            name: "ping",
            description: "Health check. Returns pong.",
            inputSchema: .object(["type": .string("object"), "properties": .object([:])])
        )
    }

    private static func searchTool() -> Tool {
        Tool(
            name: "notes_search",
            description: "Search Apple Notes by title. Returns id, title, folder, modified date and a locked flag. "
                + "Does not return note contents.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "query": .object(["type": .string("string"), "description": .string("Text to find in titles")]),
                    "folder": .object(["type": .string("string"), "description": .string("Exact folder name")]),
                    "since": .object(["type": .string("string"), "description": .string("Only notes modified after this ISO date")]),
                    "limit": .object(["type": .string("integer"), "description": .string("Max results, default 25, max 50")])
                ])
            ])
        )
    }
}
