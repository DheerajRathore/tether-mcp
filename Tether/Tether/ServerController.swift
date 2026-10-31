//
//  ServerController.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 29/10/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ServerController {
    var isRunning = false
    var errorMessage: String?
    private let host = MCPHost()
    let notes = NotesAccess()

    init() {
        let host = self.host
        notes.onFolderChange = { url in
            Task { await host.setNotesFolder(url) }
        }
        notes.publishCurrentFolder()
    }

    func setEnabled(_ enabled: Bool) {
        Task {
            do {
                if enabled { try await host.start() } else { await host.stop() }
                isRunning = enabled
                errorMessage = nil
            } catch {
                isRunning = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
