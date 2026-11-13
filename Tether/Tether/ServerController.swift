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
    private static let enabledKey = "serverEnabled"

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

        // Auto-start unless the user switched the server off last time.
        let wanted = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        if wanted { setEnabled(true) }
        print("ServerController init, wanted:", wanted)

    }

    func setEnabled(_ enabled: Bool) {
        print("setEnabled:", enabled)
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
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
