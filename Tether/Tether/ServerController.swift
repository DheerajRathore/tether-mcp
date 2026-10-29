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
