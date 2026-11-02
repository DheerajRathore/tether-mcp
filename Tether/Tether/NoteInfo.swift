//
//  NoteInfo.swift
//  Tether
//
//  Created by Dheeraj Singh Rathore on 02/11/26.
//

import Foundation

struct NoteInfo: Codable, Sendable {
    let id: String
    let title: String
    let folder: String?
    let modified: String?
    let locked: Bool
}

struct SearchOutput: Codable, Sendable {
    let notes: [NoteInfo]
    /// Notes that could only be matched by title because their contents couldn't be decoded.
    let unreadableCount: Int
}
