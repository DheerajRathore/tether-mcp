//
//  NotesAccess.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 31/10/26.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class NotesAccess {
    enum Status: Equatable {
        case notChosen
        case connected
        case error(String)
    }

    private(set) var status: Status = .notChosen
    private(set) var folderURL: URL?
    private(set) var summaryText: String?
    private let bookmarkKey = "notesFolderBookmark"

    init() { restore() }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.message = "Select the Apple Notes data folder (group.com.apple.notes)"
        panel.prompt = "Allow Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: realHome())
            .appendingPathComponent("Library/Group Containers/group.com.apple.notes")

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let dbPath = url.appendingPathComponent("NoteStore.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            status = .error("That folder has no NoteStore.sqlite. Pick group.com.apple.notes.")
            return
        }
        do {
            let data = try url.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            activate(url)
        } catch {
            status = .error("Could not save access: \(error.localizedDescription)")
        }
    }

    func forget() {
        folderURL?.stopAccessingSecurityScopedResource()
        folderURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        summaryText = nil
        status = .notChosen
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope) {
                UserDefaults.standard.set(fresh, forKey: bookmarkKey)
            }
            activate(url)
        } catch {
            status = .error("Saved access is no longer valid. Choose the folder again.")
        }
    }

    private func activate(_ url: URL) {
        if url.startAccessingSecurityScopedResource() {
            folderURL = url
            status = .connected
            refreshSummary()
        } else {
            status = .error("macOS denied access to the folder.")
        }
    }

    private func realHome() -> String {
        // In a sandbox, NSHomeDirectory() is the app container, so ask for the real home.
        guard let entry = getpwuid(getuid()) else { return NSHomeDirectory() }
        return String(cString: entry.pointee.pw_dir)
    }

    func refreshSummary() {
        guard let folder = folderURL else { summaryText = nil; return }
        Task {
            do {
                let summary = try await Task.detached { try NotesDatabase.summarize(folder: folder) }.value
                summaryText = "\(summary.total) notes (\(summary.locked) locked)"
            } catch {
                summaryText = nil
                status = .error(error.localizedDescription)
            }
        }
    }
}
