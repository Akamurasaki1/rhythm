//
//  PlayHistory.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/18.
//

import Foundation

// シンプルなプレイ履歴レコード
public struct PlayRecord: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let sheetFilename: String?    // 保存可能な譜面識別子（filename）
    public let sheetTitle: String?       // 表示用タイトル（保存当時のもの）
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

// Persistence helpers (UserDefaults JSON under key)
public enum PlayHistoryStorage {
    private static let key = "playHistory.v1"

    public static func load() -> [PlayRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            let arr = try JSONDecoder().decode([PlayRecord].self, from: data)
            return arr
        } catch {
            print("DBG: PlayHistoryStorage.load decode failed: \(error)")
            return []
        }
    }

    public static func save(_ records: [PlayRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("DBG: PlayHistoryStorage.save encode failed: \(error)")
        }
    }

    public static func append(_ record: PlayRecord, limit: Int = 200) {
        var current = load()
        current.insert(record, at: 0) // newest first
        if current.count > limit {
            current = Array(current.prefix(limit))
        }
        save(current)
    }
}
