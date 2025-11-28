//
//  ResultsView.swift
//  SYNqFliQ
//
//  Combined results screen: includes both the "minimal" layout you provided
//  and the richer UI (medal, distribution bar, share/save/play again/back).
//  Use from ContentView via .sheet(isPresented:) and pass the result values.
//
//  Created by assistant on 2025/11/25.
//
import SwiftUI
import UIKit

public struct ResultsView: View {
    // Core results data
    let score: Int
    let maxCombo: Int
    let perfect: Int
    let good: Int
    let ok: Int
    let miss: Int
    let cumulativeCombo: Int
    let playMaxHistory: [Int]
    let consecutiveCombo: Int
    // NEW: play count for the current sheet
    let playCount: Int
//    var scorepoint:Int
   // var HighScore:Int
    
    // Optional callbacks (ContentView can provide handlers)
    var onPlayAgain: (() -> Void)? = nil
    var onBackToSelection: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    /// onShare receives prepared activity items. If nil, this view presents a default share sheet with text.
    var onShare: ((_ items: [Any]) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing: Bool = false
    
    public init(score: Int,
          //      scorepoint:Int,
            //    HeighScore:Int,
                maxCombo: Int,
                perfect: Int,
                good: Int,
                ok: Int,
                miss: Int,
                cumulativeCombo: Int,
                playMaxHistory: [Int],
                consecutiveCombo: Int,
                playCount: Int = 0,
                onPlayAgain: (() -> Void)? = nil,
                onBackToSelection: (() -> Void)? = nil,
                onSave: (() -> Void)? = nil,
                onShare: ((_ items: [Any]) -> Void)? = nil) {
        self.score = score
   //     self.scorepoint = scorepoint
            //       self.HighScore = HeighScore
        self.maxCombo = maxCombo
        self.perfect = perfect
        self.good = good
        self.ok = ok
        self.miss = miss
        self.cumulativeCombo = cumulativeCombo
        self.playCount = playCount
        self.playMaxHistory = playMaxHistory
        self.consecutiveCombo = consecutiveCombo
        self.onPlayAgain = onPlayAgain
        self.onBackToSelection = onBackToSelection
        self.onSave = onSave
        self.onShare = onShare
    }
    
    // derived
    private var totalNotes: Int { perfect + good + ok + miss }
    private var Theoretical_optimum: Int{totalNotes*Int(3.5)} // 全部Perfect+コンボ数/2
    private var scorepoints:Int{(score+maxCombo/2)*100000000/Theoretical_optimum}
    private var perfectPct: Double { totalNotes == 0 ? 0 : Double(perfect) / Double(totalNotes) }
    private var goodPct: Double { totalNotes == 0 ? 0 : Double(good) / Double(totalNotes) }
    private var okPct: Double { totalNotes == 0 ? 0 : Double(ok) / Double(totalNotes) }
    private var missPct: Double { totalNotes == 0 ? 0 : Double(miss) / Double(totalNotes) }
    
    // ランク
    private func ScoreMedalName() -> String {
        if perfectPct > 0.9 && miss == 0 { return "SS" }
        if perfectPct > 0.75 { return "S" }
        if perfectPct > 0.5 { return "A" }
        if perfectPct > 0.3 { return "B" }
        return "C"
    }
    // FCやAP等
    private func AchievementMedalName() -> String{
        if miss == 0 && ok == 0 && good == 0 && perfect > 0 { return "AP" }
        else if miss == 0 { return "FC" }
        return "-"
    }
    
    
    public var body: some View {
        /*   VStack(spacing: 8) {
         Text("This is ResultsView")
         .font(.system(size: 48, weight: .heavy, design: .rounded))
         .foregroundColor(.white)
         .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
         } */
        NavigationView {
            VStack(spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("プレイ結果").font(.title2).foregroundColor(.secondary)
                        Text("\(scorepoints)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(.clear) // mask と overlay の重なりを正しくするためにクリアにしておく
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.red, Color.blue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .mask(
                                Text("\(scorepoints)")
                                    .font(.largeTitle).bold()
                            )
                            .shadow(radius: 6)
                        Text("(\(score))")
                            .font(.system(size: 18, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    Spacer()
                    VStack {
                        Text(ScoreMedalName())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(width: 84, height: 84)
                            .background(ScoreMedalColor().opacity(0.18))
                            .foregroundColor(ScoreMedalColor())
                            .clipShape(Circle())
                            .overlay(Circle().stroke(ScoreMedalColor().opacity(0.35), lineWidth: 3))
                    //    Text(rankSubtitle()).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack {
                        Text(AchievementMedalName())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(width: 84, height: 84)
                            .background(AchievementMedalColor().opacity(0.18))
                            .foregroundColor(AchievementMedalColor())
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AchievementMedalColor().opacity(0.35), lineWidth: 3))
                    }
                    Spacer()
                    VStack {
                        Text("Played")
                            .font(.caption).foregroundColor(.secondary)
                        Text("\(playCount)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(width: 84, height: 84)
                            .background(PlayCountMedalColor().opacity(0.18))
                            .foregroundColor(PlayCountMedalColor())
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PlayCountMedalColor().opacity(0.35), lineWidth: 3))
                        Text("time\(playCount == 1 ? "" : "s")")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Stats + distribution
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        statRow(title: "Max Combo", value: "\(maxCombo)")
                        statRow(title: "PERFECT", value: "\(perfect)")
                        statRow(title: "GOOD", value: "\(good)")
                        statRow(title: "OK", value: "\(ok)")
                        statRow(title: "MISS", value: "\(miss)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hit distribution").font(.caption).foregroundColor(.secondary)
                        distributionBar()
                            .frame(width: 160, height: 18)
                            .cornerRadius(9)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.06)))
                        Spacer()
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Notes").font(.caption).foregroundColor(.secondary)
                                Text("\(totalNotes)").bold()
                            }
                            Spacer()
                        }
                    }
                    .frame(maxWidth: 200)
                }
                .padding(.horizontal)
                
                Divider().background(Color.white.opacity(0.05))
                
                // Additional stats
                VStack(spacing: 8) {
                    HStack {
                        Text("通算連続コンボ").foregroundColor(.secondary).font(.caption)
                        Spacer()
                        Text("\(consecutiveCombo)").bold()
                    }
                    HStack {
                        Text("通算コンボ").foregroundColor(.secondary).font(.caption)
                        Spacer()
                        Text("\(cumulativeCombo)").bold()
                    }
                    if !playMaxHistory.isEmpty {
                        HStack {
                            Text("Recent Maxes").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(playMaxHistory.map { String($0) }.joined(separator: ", ")).font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Actions: Play Again / Back / Save / Share / Close (minimal + extended)
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                onPlayAgain?()
                            }
                        }) {
                            Text("Play Again")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                onBackToSelection?()
                            }
                        }) {
                            Text("Back to Selection")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        Button(action: { onSave?() }) {
                            HStack {
                                Image(systemName: "tray.and.arrow.down")
                                Text("Save")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            let items: [Any] = [shareText()]
                            if let onShare = onShare {
                                onShare(items)
                            } else {
                                // fallback: show internal share sheet
                                isSharing = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("閉じる")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .padding(.vertical)
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $isSharing) {
                ActivityViewController(activityItems: [shareText()])
            }
        }
        }


    // MARK: - Helpers / subviews

    @ViewBuilder
    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
    }

    @ViewBuilder
    private func distributionBar() -> some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                Rectangle().fill(Color.green).frame(width: g.size.width * CGFloat(perfectPct))
                Rectangle().fill(Color.blue).frame(width: g.size.width * CGFloat(goodPct))
                Rectangle().fill(Color.gray).frame(width: g.size.width * CGFloat(okPct))
                Rectangle().fill(Color.red).frame(width: g.size.width * CGFloat(missPct))
            }
        }
    }

    private func shareText() -> String {
        var s = "SYNqFliQ Result\n"
        s += "Score: \(score)\n"
        s += "Max Combo: \(maxCombo)\n"
        s += "PERFECT: \(perfect) GOOD: \(good) OK: \(ok) MISS: \(miss)\n"
        s += "Cumulative Combo: \(cumulativeCombo)\n"
        s += "Played: \(playCount)\n"
        return s
    }

    private func ScoreMedalColor() -> Color {
        switch ScoreMedalName() {
        case "SS": return Color.purple
        case "S": return Color.yellow
        case "A": return Color.green
        case "B": return Color.orange
        default: return Color.gray
        }
    }
    private func AchievementMedalColor() -> Color {
        switch AchievementMedalName() {
        case "AP": return Color.red
        case "FC": return Color.yellow
        default: return Color.gray
        }
    }
    private func PlayCountMedalColor() -> Color {
        switch playCount {
        case 10...: return Color.purple
        case 6..<10: return Color.yellow
        case 4..<6: return Color.green
        case 2..<4: return Color.orange
        default: return Color.gray
        }
    }


    private func rankSubtitle() -> String {
        switch ScoreMedalName() {
        case "SS": return "Perfect"
        case "S": return "Excellent"
        case "A": return "Great"
        case "B": return "Good"
        default: return "Keep Practicing"
        }
    }
}

// ActivityViewController wrapper for sharing
fileprivate struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Preview
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        ResultsView(score: 12345,
                  //  scorepoint: 1111111111,
                  //  HeighScore: 1112221111,
                    maxCombo: 120,
                    perfect: 200, good: 40, ok: 10, miss: 3,
                    cumulativeCombo: 1500,
                    playMaxHistory: [120, 110, 90],
                    consecutiveCombo: 75,
                    onPlayAgain: { print("Play again") },
                    onBackToSelection: { print("Back to selection") },
                    onSave: { print("Save") })
            .preferredColorScheme(.dark)
    }
}
