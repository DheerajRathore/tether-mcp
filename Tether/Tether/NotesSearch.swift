//
//  NoteInfo.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 31/10/26.
//

import Foundation
import SQLite3

struct NoteInfo: Codable, Sendable {
    let id: String
    let title: String
    let folder: String?
    let modified: String?
    let locked: Bool
}

extension NotesDatabase {
    struct SearchOptions: Sendable {
        var query: String?
        var folder: String?
        var since: Date?
        var limit: Int
    }

    private nonisolated static let searchSQL = """
        SELECT n.ZIDENTIFIER, n.ZTITLE1, f.ZTITLE2, n.ZMODIFICATIONDATE1,
               COALESCE(n.ZISPASSWORDPROTECTED, 0)
        FROM ZICCLOUDSYNCINGOBJECT n
        LEFT JOIN ZICCLOUDSYNCINGOBJECT f ON n.ZFOLDER = f.Z_PK
        WHERE n.ZNOTEDATA IS NOT NULL
          AND COALESCE(n.ZMARKEDFORDELETION, 0) = 0
          AND (?1 IS NULL OR n.ZTITLE1 LIKE '%' || ?1 || '%')
          AND (?2 IS NULL OR f.ZTITLE2 = ?2)
          AND (?3 IS NULL OR n.ZMODIFICATIONDATE1 >= ?3)
        ORDER BY n.ZMODIFICATIONDATE1 DESC
        LIMIT ?4
        """

    nonisolated static func search(folder: URL, options: SearchOptions) throws -> [NoteInfo] {
        let database = try openReadOnly(folder)
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, searchSQL, -1, &statement, nil) == SQLITE_OK else {
            throw NotesDatabaseError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        bind(statement, options)

        var notes: [NoteInfo] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            notes.append(row(statement))
        }
        return notes
    }

    private nonisolated static func openReadOnly(_ folder: URL) throws -> OpaquePointer? {
        let path = folder.appendingPathComponent("NoteStore.sqlite").path
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(database)
            throw NotesDatabaseError.openFailed(message)
        }
        sqlite3_busy_timeout(database, 2000)
        return database
    }

    private nonisolated static func bind(_ statement: OpaquePointer?, _ options: SearchOptions) {
        bindText(statement, 1, options.query)
        bindText(statement, 2, options.folder)
        if let since = options.since {
            sqlite3_bind_double(statement, 3, since.timeIntervalSinceReferenceDate)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(options.limit))
    }

    private nonisolated static func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        guard let value, !value.isEmpty else {
            sqlite3_bind_null(statement, index)
            return
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, value, -1, transient)
    }

    private nonisolated static func text(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: cString)
    }

    private nonisolated static func row(_ statement: OpaquePointer?) -> NoteInfo {
        var modified: String?
        if sqlite3_column_type(statement, 3) != SQLITE_NULL {
            let seconds = sqlite3_column_double(statement, 3)
            modified = ISO8601DateFormatter().string(from: Date(timeIntervalSinceReferenceDate: seconds))
        }
        return NoteInfo(
            id: text(statement, 0) ?? "",
            title: text(statement, 1) ?? "(untitled)",
            folder: text(statement, 2),
            modified: modified,
            locked: sqlite3_column_int(statement, 4) == 1
        )
    }
}
