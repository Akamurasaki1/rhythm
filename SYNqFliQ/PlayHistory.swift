//
//  PlayHistory.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/18.
//

//
// PlayHistory.swift
// Centralized PlayRecord & storage
//

import Foundation

public struct PlayRecord: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let sheetFilename: String?
    public let sheetTitle: String?
    public let score: Int
    public let maxCombo: Int
    public let perfectCount: Int
    public let goodCount: Int
    public let okCount: Int
    public let missCount: Int

    public init(date: Date = Date(),
                sheetFilename: String?,
                sheetTitle: String?,
                score: Int,
                maxCombo: Int,
                perfectCount: Int,
                goodCount: Int,
                okCount: Int,
                missCount: Int) {
        self.id = UUID()
        self.date = date
        self.sheetFilename = sheetFilename
        self.sheetTitle = sheetTitle
        self.score = score
        self.maxCombo = maxCombo
        self.perfectCount = perfectCount
        self.goodCount = goodCount
        self.okCount = okCount
        self.missCount = missCount
    }
}

public enum PlayHistoryStorage {
    private static let key = "playHistory.v1"

    public static func load() -> [PlayRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([PlayRecord].self, from: data)
        } catch {
            print("DBG: PlayHistoryStorage.load decode failed:", error)
            return []
        }
    }

    public static func save(_ records: [PlayRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("DBG: PlayHistoryStorage.save encode failed:", error)
        }
    }

    public static func append(_ record: PlayRecord, limit: Int = 300) {
        var current = load()
        current.insert(record, at: 0)
        if current.count > limit { current = Array(current.prefix(limit)) }
        save(current)
    }
}
