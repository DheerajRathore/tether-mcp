//
//  TrustedClientsSection.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 27/11/26.
//

import AppKit
import SwiftUI

struct TrustedClientsSection: View {
    @State private var count = TrustStore.count

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(count == 0 ? "No trusted clients" : "\(count) trusted client(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset trusted clients") { confirmReset() }
                .disabled(count == 0)
        }
        .onAppear { count = TrustStore.count }
    }

    private func confirmReset() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reset trusted clients?"
        alert.informativeText = "Tether will ask again the next time a client connects. "
            + "Clients that are already connected stay connected."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        TrustStore.reset()
        count = TrustStore.count
    }
}
