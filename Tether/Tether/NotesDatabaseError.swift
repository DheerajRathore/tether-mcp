//
//  NotesDatabaseError.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 31/10/26.
//

import Foundation
import SQLite3

enum NotesDatabaseError: LocalizedError {
    case openFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): return "Could not open Notes database: \(message)"
        case .queryFailed(let message): return "Notes query failed: \(message)"
        }
    }
}

enum NotesDatabase {
    struct Summary: Sendable {
        let total: Int
        let locked: Int
    }

    nonisolated static func summarize(folder: URL) throws -> Summary {
        let path = folder.appendingPathComponent("NoteStore.sqlite").path
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(database)
            throw NotesDatabaseError.openFailed(message)
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 2000)

        let base = "FROM ZICCLOUDSYNCINGOBJECT WHERE ZNOTEDATA IS NOT NULL AND COALESCE(ZMARKEDFORDELETION, 0) = 0"
        let total = try scalar(database, "SELECT COUNT(*) \(base)")
        let locked = try scalar(database, "SELECT COUNT(*) \(base) AND COALESCE(ZISPASSWORDPROTECTED, 0) = 1")
        return Summary(total: total, locked: locked)
    }

    private nonisolated static func scalar(_ database: OpaquePointer?, _ sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NotesDatabaseError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw NotesDatabaseError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        return Int(sqlite3_column_int64(statement, 0))
    }
}
