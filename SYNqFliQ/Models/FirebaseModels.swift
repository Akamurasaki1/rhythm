//
//  UserProfile.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/23.
//


import Foundation

// Firebase 用のモデル群（Notes モデルとは別に分離）
public struct UserProfile: Codable {
    public var uid: String
    public var displayName: String?
    public var iconURL: String?         // storage URL 等
    public var createdAt: Date?

    public init(uid: String, displayName: String? = nil, iconURL: String? = nil, createdAt: Date? = Date()) {
        self.uid = uid
        self.displayName = displayName
        self.iconURL = iconURL
        self.createdAt = createdAt
    }
}

/// Firebase に保存する用途の PlayRecord（ローカルの PlayRecord と名前がぶつからないよう別名に）
public struct CloudPlayRecord: Codable, Identifiable {
    public var id: String
    public var date: Date
    public var sheetId: String?
    public var sheetTitle: String?
    public var score: Int
    public var maxCombo: Int
    public var perfect: Int
    public var good: Int
    public var ok: Int
    public var miss: Int
    public var cumulativeCombo: Int?
    public var playDeviceId: String?

    public init(id: String = UUID().uuidString,
                date: Date = Date(),
                sheetId: String? = nil,
                sheetTitle: String? = nil,
                score: Int = 0,
                maxCombo: Int = 0,
                perfect: Int = 0,
                good: Int = 0,
                ok: Int = 0,
                miss: Int = 0,
                cumulativeCombo: Int? = nil,
                playDeviceId: String? = nil) {
        self.id = id
        self.date = date
        self.sheetId = sheetId
        self.sheetTitle = sheetTitle
        self.score = score
        self.maxCombo = maxCombo
        self.perfect = perfect
        self.good = good
        self.ok = ok
        self.miss = miss
        self.cumulativeCombo = cumulativeCombo
        self.playDeviceId = playDeviceId
    }
}

public struct FavoritesContainer: Codable {
    public var favorites: [String]
    public init(favorites: [String] = []) { self.favorites = favorites }
}

public struct CurrencyState: Codable {
    public var amount: Int
    public init(amount: Int = 0) { self.amount = amount }
}
