//
//  ClaudeConfigSection.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 16/11/26.
//

import SwiftUI

struct ClaudeConfigSection: View {
    let configurator: ClaudeConfigurator

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusText)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            Button(buttonTitle) { configurator.configure() }
        }
        .onAppear { configurator.refreshStatus() }
    }

    private var buttonTitle: String {
        switch configurator.status {
        case .configured: return "Re-apply Claude Desktop Config"
        case .stalePath: return "Update Claude Desktop Config"
        default: return "Configure Claude Desktop"
        }
    }

    private var statusText: String {
        switch configurator.status {
        case .unknown, .notConfigured: return "Not configured yet"
        case .configured: return "Configured. Restart Claude Desktop if tools are missing."
        case .stalePath: return "Config points to a different Tether location"
        case .failed(let message): return message
        }
    }
}
