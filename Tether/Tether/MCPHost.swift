//
//  MCPHost.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 29/10/26.
//

import Foundation
import MCP
import Network
import TopoText

actor MCPHost {
    private static let maxNoteCharacters = 50_000
    private static let notConnected = "Notes folder not connected. Open Tether and choose the Notes folder."

    private var listener: NWListener?
    private var sessions: [ObjectIdentifier: (NWConnection, Server)] = [:]
    private var store: Store?

    func start() throws {
        guard listener == nil else { return }
        let newListener = try NWListener(using: .tcp)
        newListener.service = NWListener.Service(name: "Tether", type: "_mcp._tcp")
        newListener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }
        newListener.start(queue: .global())
        listener = newListener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (connection, _) in sessions.values { connection.cancel() }
        sessions.removeAll()
    }

    func setNotesFolder(_ url: URL?) {
        store = url.map { Store(root: $0) }
    }

    private func accept(_ connection: NWConnection) async {
        let server = Server(
            name: "Tether",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        await registerTools(on: server)
//        do {
//            try await server.start(
//                transport: NetworkTransport(connection: connection, heartbeatConfig: .disabled)
//            )
//            sessions[ObjectIdentifier(connection)] = (connection, server)
//        } catch {
//            connection.cancel()
//        }
        do {
            try await server.start(
                transport: NetworkTransport(connection: connection, heartbeatConfig: .disabled)
            ) { [weak self] clientInfo, _ in
                do {
                    try await Self.authorize(clientName: clientInfo.name)
                } catch {
                    await self?.drop(connection)
                    throw error
                }
            }
            sessions[ObjectIdentifier(connection)] = (connection, server)
            await watch(connection)
        } catch {
            connection.cancel()
        }
    }

    private func registerTools(on server: Server) async {
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [Self.pingTool(), Self.searchTool(), Self.readTool()])
        }
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else { return Self.errorResult("Server stopped") }
            return await self.call(name: params.name, arguments: params.arguments)
        }
    }

    private func call(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        switch name {
        case "ping": return Self.textResult("pong")
        case "notes_search": return await searchNotes(arguments)
        case "notes_read": return await readNote(arguments)
        default: return Self.errorResult("Unknown tool: \(name)")
        }
    }

    // MARK: - notes_search

    private func searchNotes(_ arguments: [String: Value]?) async -> CallTool.Result {
        guard let store else { return Self.errorResult(Self.notConnected) }
        do {
            let folders = try await store.folders()
            var folderIDs: Set<Folder.ID>?
            if let wanted = arguments?["folder"]?.stringValue, !wanted.isEmpty {
                let matches = folders.filter { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }
                guard !matches.isEmpty else { return Self.errorResult("No folder named \"\(wanted)\".") }
                folderIDs = Set(matches.map(\.id))
            }
            let request = Note.FetchRequest(
                query: arguments?["query"]?.stringValue,
                folderIDs: folderIDs,
                startDate: Self.parseDate(arguments?["since"]?.stringValue),
                limit: min(max(arguments?["limit"]?.intValue ?? 25, 1), Note.FetchRequest.maximumLimit)
            )
            let result = try await store.search(request)
            let names = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.name) })
            let formatter = ISO8601DateFormatter()
            let notes = result.notes.map { note in
                NoteInfo(
                    id: note.id.description,
                    title: note.title,
                    folder: note.folderID.flatMap { names[$0] },
                    modified: note.modificationDate.map { formatter.string(from: $0) },
                    locked: note.isLocked
                )
            }
            let output = SearchOutput(notes: notes, unreadableCount: result.unreadableNoteIDs.count)
            let data = try JSONEncoder().encode(output)
            guard let json = String(data: data, encoding: .utf8) else {
                return Self.errorResult("Could not encode search results.")
            }
            return Self.textResult(json)
        } catch {
            return Self.errorResult(error.localizedDescription)
        }
    }

    // MARK: - notes_read

    private func readNote(_ arguments: [String: Value]?) async -> CallTool.Result {
        guard let store else { return Self.errorResult(Self.notConnected) }
        guard let idText = arguments?["id"]?.stringValue, let noteID = Note.ID(idText) else {
            return Self.errorResult("Missing or invalid note id. Use an id returned by notes_search.")
        }
        do {
            let note = try await store.note(for: noteID)
            if note.isLocked {
                return Self.errorResult("\"\(note.title)\" is password-locked. Its contents can't be read.")
            }
            let markdown = try await store.content(for: noteID).markdown()
            var body = markdown
            var truncated = false
            if markdown.count > Self.maxNoteCharacters {
                body = String(markdown.prefix(Self.maxNoteCharacters))
                truncated = true
            }
            var output = "# \(note.title)\n\n\(body)"
            if truncated { output += "\n\n[Note truncated at \(Self.maxNoteCharacters) characters]" }
            return Self.textResult(output)
        } catch {
            return Self.errorResult(error.localizedDescription)
        }
    }

    // MARK: - Helpers

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

    private static func property(_ type: String, _ description: String) -> Value {
        .object(["type": .string(type), "description": .string(description)])
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
            description: "Search Apple Notes by title and contents. Returns id, title, folder, modified date "
                + "and a locked flag. Does not return note contents; use notes_read for that.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "query": property("string", "Text to find in notes"),
                    "folder": property("string", "Folder name"),
                    "since": property("string", "Only notes modified after this ISO date"),
                    "limit": property("integer", "Max results, default 25")
                ])
            ])
        )
    }

    private static func readTool() -> Tool {
        Tool(
            name: "notes_read",
            description: "Read one Apple Note as Markdown, by the id returned from notes_search. "
                + "Locked notes can't be read.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object(["id": property("string", "Note id from notes_search")]),
                "required": .array([.string("id")])
            ])
        )
    }

    /// Removes the session once its connection closes.
    private func watch(_ connection: NWConnection) async {
        connection.stateUpdateHandler = { [weak self] state in
            if Self.isClosed(state) {
                Task { await self?.drop(connection) }
            }
        }
        // The connection may already have closed before the handler was set.
        if Self.isClosed(connection.state) { await drop(connection) }
    }

    private static func isClosed(_ state: NWConnection.State) -> Bool {
        switch state {
        case .failed, .cancelled: return true
        default: return false
        }
    }

    // MARK: - Helpers:

    private static func authorize(clientName: String) async throws {
        if TrustStore.isTrusted(clientName) { return }
        let allowed = await ConnectionApprover.ask(clientName: clientName)
        guard allowed else { throw MCPError.invalidRequest("Connection denied by the user.") }
    }

//    private func drop(_ connection: NWConnection) {
//        sessions[ObjectIdentifier(connection)] = nil
//        connection.cancel()
//    }
    private func drop(_ connection: NWConnection) async {
        let session = sessions.removeValue(forKey: ObjectIdentifier(connection))
        connection.cancel()
        await session?.1.stop()
    }
}
