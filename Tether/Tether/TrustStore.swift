//
//  TrustStore.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 10/11/26.
//

import Foundation

/// Remembers which MCP clients the user chose to always trust.
struct TrustStore: Sendable {
    private static let key = "trustedClients"

    static func isTrusted(_ name: String) -> Bool {
        trusted().contains(name)
    }

    static func trust(_ name: String) {
        var names = trusted()
        names.insert(name)
        UserDefaults.standard.set(Array(names).sorted(), forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func trusted() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
}
