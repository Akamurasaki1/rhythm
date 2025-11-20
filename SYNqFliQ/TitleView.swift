//
//  TitleView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/18.
//
import SwiftUI

struct TitleView: View {
    // Called when the user presses Start
    var onStart: (() -> Void)?

    // Optional callbacks
    var onOpenSettings: (() -> Void)? = nil
    var onShowCredits: (() -> Void)? = nil
    var onShowTutorial: (() -> Void)? = nil

    // Local visual state
    @State private var showSubtitle = false
    @State private var logoScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 背景（既存の背景画像 state に差し替えたい場合はここを変更）
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer().frame(height: 36)
                
                ZStack(alignment:.topLeading){
                    Button(action:{
                        onShowTutorial?()
                    }){
                        Text("Tutorial")
                    }
                }.background(Color.red)
                
                // ロゴ
                VStack(spacing: 8) {
                    Text("SYNqFliQ")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(logoScale)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)

                    if showSubtitle {
                        Text("Rhythm Game Prototype")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 24)

                Spacer()

                // Start ボタン（中央に大きく）
                Button(action: {
                    // 簡単なタップアニメーション
                    withAnimation(.easeOut(duration: 0.12)) {
                        logoScale = 0.96
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring()) {
                            logoScale = 1.0
                        }
                        // 呼び出し側へ通知してメイン画面へ遷移
                        onStart?()
                    }
                }) {
                    Text("Start")
                        .font(.title2)
                        .bold()
                        .frame(minWidth: 200, minHeight: 48)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.green, Color.blue]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 6)
                }

                // 小さめのボタン群
                
                HStack(spacing: 12) {
                    Button(action: {
                        onOpenSettings?()
                    }) {
                        Text("Settings")
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        onShowCredits?()
                    }) {
                        Text("Credits")
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 8)

                Spacer().frame(height: 36)

                // フッター（バージョン等）
                Text("Version 0.1")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                showSubtitle = true
            }
        }
    }
}

// Preview
struct TitleView_Previews: PreviewProvider {
    static var previews: some View {
        TitleView(onStart: {})
            .preferredColorScheme(.dark)
    }
}
