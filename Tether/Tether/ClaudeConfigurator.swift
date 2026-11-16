//
//  ClaudeConfigurator.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 16/11/26.
//

import AppKit
import Foundation
import Observation

/// Writes the bundled tether-cli path into Claude Desktop's config, keeping every other entry.
@MainActor
@Observable
final class ClaudeConfigurator {
    private(set) var status: Status = .unknown
    private let bookmarkKey = "claudeConfigFolderBookmark"
    private let fileName = "claude_desktop_config.json"
    enum Status: Equatable {
        case unknown, notConfigured, configured
        case stalePath(String)
        case failed(String)
    }

    enum ConfigError: LocalizedError {
        case cliMissing, translocated, wrongFolder, invalidJSON, badShape

        var errorDescription: String? {
            switch self {
            case .cliMissing: return "tether-cli was not found inside the app bundle."
            case .translocated: return "Move Tether to /Applications and reopen it, then try again."
            case .wrongFolder: return "Please choose the folder named \"Claude\"."
            case .invalidJSON: return "The existing config is not valid JSON. Nothing was changed."
            case .badShape: return "\"mcpServers\" in the config is not an object. Nothing was changed."
            }
        }
    }
    var cliPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/tether-cli").path
    }

    // MARK: - Public

    func refreshStatus() {
        guard let folder = resolveBookmark(), folder.startAccessingSecurityScopedResource() else {
            status = .notConfigured
            return
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            let root = try readConfig(in: folder)
            let servers = root["mcpServers"] as? [String: Any]
            let command = (servers?["tether"] as? [String: Any])?["command"] as? String
            switch command {
            case nil: status = .notConfigured
            case cliPath: status = .configured
            default: status = .stalePath(command ?? "")
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func configure() {
        do {
            try preflight()
            guard let folder = try obtainFolder() else { return }
            guard folder.startAccessingSecurityScopedResource() else { throw ConfigError.wrongFolder }
            defer { folder.stopAccessingSecurityScopedResource() }
            guard confirmWrite() else { return }
            var root = try readConfig(in: folder)
            try backup(in: folder)
            try merge(into: &root)
            try write(root, in: folder)
            status = .configured
            showDone()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Steps

    private func preflight() throws {
        guard FileManager.default.isExecutableFile(atPath: cliPath) else { throw ConfigError.cliMissing }
        if cliPath.contains("AppTranslocation") { throw ConfigError.translocated }
    }

    private func readConfig(in folder: URL) throws -> [String: Any] {
        let url = folder.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigError.invalidJSON
        }
        return root
    }

    private func backup(in folder: URL) throws {
        let source = folder.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let target = folder.appendingPathComponent(fileName + ".bak")
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: source, to: target)
    }

    private func merge(into root: inout [String: Any]) throws {
        var servers: [String: Any] = [:]
        if let existing = root["mcpServers"] {
            guard let dict = existing as? [String: Any] else { throw ConfigError.badShape }
            servers = dict
        }
        var entry = servers["tether"] as? [String: Any] ?? [:]
        entry["command"] = cliPath
        servers["tether"] = entry
        root["mcpServers"] = servers
    }

    private func write(_ root: [String: Any], in folder: URL) throws {
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try JSONSerialization.data(withJSONObject: root, options: options)
        data.append(0x0A)
        try data.write(to: folder.appendingPathComponent(fileName), options: .atomic)
    }

    // MARK: - Folder access

    private func obtainFolder() throws -> URL? {
        if let saved = resolveBookmark() { return saved }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = realHome.appendingPathComponent("Library/Application Support/Claude")
        panel.message = "Choose the Claude folder so Tether can add itself to Claude Desktop's config."
        panel.prompt = "Grant Access"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard url.lastPathComponent == "Claude" else { throw ConfigError.wrongFolder }
        saveBookmark(for: url)
        return url
    }

    private func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { saveBookmark(for: url) }
        return url
    }

    private func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope) else { return }
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    /// Real home folder; inside the sandbox, homeDirectoryForCurrentUser is the container.
    private var realHome: URL {
        guard let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: dir))
    }

    // MARK: - Alerts

    private func confirmWrite() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Add Tether to Claude Desktop?"
        alert.informativeText = "Tether will add one entry to claude_desktop_config.json. "
            + "Your other servers stay as they are, and a backup is saved as claude_desktop_config.json.bak."
        alert.addButton(withTitle: "Update Config")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showDone() {
        let alert = NSAlert()
        alert.messageText = "Done"
        alert.informativeText = "Quit Claude Desktop (Cmd+Q) and reopen it to load Tether."
        alert.runModal()
    }
}
