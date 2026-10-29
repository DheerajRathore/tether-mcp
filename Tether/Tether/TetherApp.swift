//
//  TetherApp.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 28/10/26.
//

import SwiftUI

@main
struct TetherApp: App {
    @State private var controller = ServerController()

    var body: some Scene {
        MenuBarExtra("Tether", systemImage: "link") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable MCP server", isOn: Binding(
                    get: { controller.isRunning },
                    set: { controller.setEnabled($0) }
                ))
                Text(controller.isRunning ? "Server running" : "Server stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = controller.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Divider()
                Button("Quit Tether") { NSApplication.shared.terminate(nil) }
            }
            .padding(12)
            .frame(width: 240)
        }
        .menuBarExtraStyle(.window)
    }
}
