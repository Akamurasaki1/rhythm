import Foundation
import SwiftUI
import CoreGraphics

/// Documents 等のファイル管理で使う簡易ユーティリティ
enum SheetFileManager {
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

/// 正規化された座標（0.0..1.0 の想定）
public struct NormalizedPosition: Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0.5, y: Double = 0.5) {
        self.x = x
        self.y = y
    }
}

/// Sheet 内で定義されるノーツの形式（JSON 側の正しい形）
/// id は譜面側で持つ識別子（string）
public struct SheetNote: Codable, Equatable {
    public var id: String
    public var time: Double
    public var angleDegrees: Double
    public var normalizedPosition: NormalizedPosition
    public var noteType:String?
    public var holdEndTime:Double?
    public init(id: String, time: Double, angleDegrees: Double, normalizedPosition: NormalizedPosition) {
        self.id = id
        self.time = time
        self.angleDegrees = angleDegrees
        self.normalizedPosition = normalizedPosition
    }
}

/// Bundle / file から読み込む Sheet の定義
public struct Sheet: Codable, Equatable {
    public var version: Int?
    public var title: String
    public var difficulty: String?
    public var level: Int?
    public var id: String?
    public var bpm: Double?
    public var audioFilename: String?
    public var backgroundFilename: String?
    public var notes: [SheetNote]
    public var offset: Double?

    public init(title: String = "Untitled", notes: [SheetNote] = [], audioFilename: String? = nil) {
        self.title = title
        self.notes = notes
        self.audioFilename = audioFilename
    }
}

/// アプリ内で再生に使うノーツ表現（normalizedPosition を CGPoint で保持）
public struct Note: Equatable {
    public var id: String?            // 元の SheetNote.id を保存しておく（任意）
    public var SourceID: String?
    public var time: Double
    public var angleDegrees: Double
    public var normalizedPosition: CGPoint

    public init(id: String? = nil, time: Double, angleDegrees: Double, normalizedPosition: CGPoint) {
        self.id = id
        self.time = time
        self.angleDegrees = angleDegrees
        self.normalizedPosition = normalizedPosition
    }
}

extension Note {
    /// SheetNote から Note へ安全に変換するイニシャライザ（clamp して安全化）
    public init(from sheetNote: SheetNote) {
        self.id = sheetNote.id
        self.time = sheetNote.time
        self.angleDegrees = sheetNote.angleDegrees
        let nx = sheetNote.normalizedPosition.x.isFinite ? sheetNote.normalizedPosition.x : 0.5
        let ny = sheetNote.normalizedPosition.y.isFinite ? sheetNote.normalizedPosition.y : 0.5
        let clampedX = min(max(0.0, nx), 1.0)
        let clampedY = min(max(0.0, ny), 1.0)
        self.normalizedPosition = CGPoint(x: clampedX, y: clampedY)
    }
}

/// Helper: SheetNote 配列を Note 配列に変換
extension Array where Element == SheetNote {
    func asNotes() -> [Note] {
        self.map { Note(from: $0) }
    }
}

/// CGPoint を Codable として扱うためのエンコード/デコード実装（補助）
extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let x = try c.decode(CGFloat.self, forKey: .x)
        let y = try c.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self.x, forKey: .x)
        try c.encode(self.y, forKey: .y)
    }

    enum CodingKeys: String, CodingKey {
        case x, y
    }
}
