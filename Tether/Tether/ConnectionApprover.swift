//
//  ConnectionApprover.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 10/11/26.
//

import AppKit

/// Asks the user whether an MCP client may connect.
@MainActor
enum ConnectionApprover {
    static func ask(clientName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Allow \"\(clientName)\" to access your Notes?"
        alert.informativeText = "This app can search and read your Apple Notes through Tether."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Always trust this client"

        NSApp.activate(ignoringOtherApps: true)
        let allowed = alert.runModal() == .alertFirstButtonReturn
        if allowed, alert.suppressionButton?.state == .on {
            TrustStore.trust(clientName)
        }
        return allowed
    }
}
