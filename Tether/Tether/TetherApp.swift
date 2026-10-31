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
    @State private var notes = NotesAccess()

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
                Text("Notes").font(.headline)
                switch notes.status {
                case .notChosen:
                    Button("Choose Notes folder…") { notes.chooseFolder() }
                case .connected:
                    HStack {
                        Text("Connected").font(.caption).foregroundStyle(.green)
                        Spacer()
                        Button("Forget") { notes.forget() }.buttonStyle(.link)
                    }
                    if let summary = notes.summaryText {
                        Text(summary).font(.caption).foregroundStyle(.secondary)
                    }
                case .error(let message):
                    Text(message).font(.caption).foregroundStyle(.red)
                    Button("Choose Notes folder…") { notes.chooseFolder() }
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
