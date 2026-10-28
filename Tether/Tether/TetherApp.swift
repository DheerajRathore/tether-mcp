//
//  TetherApp.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 28/10/26.
//

import SwiftUI

@main
struct TetherApp: App {
    @AppStorage("serverEnabled") private var serverEnabled = false

    var body: some Scene {
        MenuBarExtra("Tether", systemImage: "link") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable MCP server", isOn: $serverEnabled)
                Text(serverEnabled ? "Server running" : "Server stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                Button("Quit Tether") { NSApplication.shared.terminate(nil) }
            }
            .padding(12)
            .frame(width: 240)
        }
        .menuBarExtraStyle(.window)
    }
}
