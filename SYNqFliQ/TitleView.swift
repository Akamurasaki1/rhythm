//
//  TitleView.swift
//  SYNqFliQ
//
//  Layout & shape-focused TitleView:
//  - Central circle (200pt) with a soft two-tone split (soft blurred boundary).
//  - Two crescent-shaped buttons hugging the central circle (diagonally).
//  - Central circle visually "punches" into crescents (destinationOut) so crescents look cut.
//  - Uses your provided FloatingButton implementation unchanged for all three buttons.
//  - Each button is placed in its own VStack as you requested (keeps layout semantics).
//
//  Tweakable parameters are commented where useful (sizes / offsets / stroke widths / blur radius).
//

import SwiftUI
import FirebaseAuth

// MARK: - Crescent shape: outer circle minus inner circle (even-odd fill)
struct CrescentShape: Shape {
    var innerAngle: CGFloat = .pi
    var innerOffsetFraction: CGFloat = 0.62
    var innerRadiusRatio: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let outerR = min(rect.width, rect.height) / 2.0
        let innerR = outerR * innerRadiusRatio
        let maxOffset = max(0, outerR - innerR)
        let offset = maxOffset * innerOffsetFraction
        let innerCx = cx + cos(innerAngle) * offset
        let innerCy = cy + sin(innerAngle) * offset

        var p = Path()
        p.addEllipse(in: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
        p.addEllipse(in: CGRect(x: innerCx - innerR, y: innerCy - innerR, width: innerR * 2, height: innerR * 2))
        return p
    }
}

// MARK: - SplitCircleView
// Renders a circle that is visually split into two colors with a soft blurred boundary.
// Implementation: draw a base (light) circle, overlay a darker circle offset a bit to the left,
// blur the dark overlay for a soft edge, then mask to the central circle so the outside remains transparent.
struct SplitCircleView: View {
    var diameter: CGFloat = 200
    var leftColor: Color = Color(red: 0.58, green: 0.18, blue: 0.18) // burgundy
    var rightColor: Color = Color(red: 0.66, green: 0.88, blue: 0.88) // pale aqua
    var darkOffsetX: CGFloat = -36 // how much left-dark patch is offset (controls curve)
    var blurRadius: CGFloat = 18    // softness of the division

    var body: some View {
        ZStack {
            // right / base color
            Circle()
                .fill(rightColor)
                .frame(width: diameter, height: diameter)

            // left darker patch: offset circle blurred and masked to main circle
            Circle()
                .fill(leftColor)
                .frame(width: diameter, height: diameter)
                .offset(x: darkOffsetX)
                .blur(radius: blurRadius)
                .compositingGroup() // isolate blur before masking
                .mask(
                    Circle()
                        .frame(width: diameter, height: diameter)
                )

            // small crisp inner boundary highlight (on the right side) to suggest depth
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 6)
                .frame(width: diameter - 2, height: diameter - 2)
                .blendMode(.overlay)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Color.black.opacity(0.32), radius: 12, x: 0, y: 8)
    }
}

// MARK: - CrescentView
// Visual content for the crescent-shaped control. Does NOT itself handle taps — that's wrapped by FloatingButton.
struct CrescentView<Content: View>: View {
    var size: CGFloat
    var innerAngle: Angle
    var innerOffsetFraction: CGFloat = 0.62
    var innerRadiusRatio: CGFloat = 0.62
    var gradient: LinearGradient? = nil
    var color: Color? = nil
    var strokeWidth: CGFloat = 4.0
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            // Fill the crescent
            if let g = gradient {
                CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                              innerOffsetFraction: innerOffsetFraction,
                              innerRadiusRatio: innerRadiusRatio)
                    .fill(g, style: FillStyle(eoFill: true, antialiased: true))
                    .frame(width: size, height: size)
            } else if let c = color {
                CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                              innerOffsetFraction: innerOffsetFraction,
                              innerRadiusRatio: innerRadiusRatio)
                    .fill(c, style: FillStyle(eoFill: true, antialiased: true))
                    .frame(width: size, height: size)
            } else {
                CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                              innerOffsetFraction: innerOffsetFraction,
                              innerRadiusRatio: innerRadiusRatio)
                    .fill(Color.yellow.opacity(0.9), style: FillStyle(eoFill: true, antialiased: true))
                    .frame(width: size, height: size)
            }

            // Black outline similar to your sketch: stroke applies to both outer and inner arcs
            CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                          innerOffsetFraction: innerOffsetFraction,
                          innerRadiusRatio: innerRadiusRatio)
                .stroke(Color.black, lineWidth: strokeWidth)
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 2)

            // content (icon + label)
            content()
                .foregroundColor(.black)
                // nudge content slightly toward the visible bulge side so text sits on the crescent area
                .offset(x: (size * 0.12) * cos(innerAngle.radians))
        }
        .frame(width: size, height: size)
        .compositingGroup()
    }
}

// MARK: - TitleView
struct TitleView: View {
    var onStart: (() -> Void)?
    var onOpenSettings: (() -> Void)? = nil
    var onShowCredits: (() -> Void)? = nil
    var onShowTutorial: (() -> Void)? = nil
    var onShowHistories: (() -> Void)? = nil
    var onShowChapters: (() -> Void)? = nil

    @State private var showSubtitle = false
    @State private var logoScale: CGFloat = 1.0
    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var firestore = FirestoreManager.shared

    enum ActiveSheet: Identifiable {
        case signIn, account
        var id: Int {
            switch self {
            case .signIn: return 1
            case .account: return 2
            }
        }
    }
    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Group {
                    if UIImage(named: "title_bg") != nil {
                        Image("title_bg")
                            .resizable(capInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) // 全体に表示？
                            .scaledToFill()
                            .frame(maxWidth:geo.size.width,maxHeight: .infinity) // 横幅に合わせることで、縦長画面でも変にならない
                            .ignoresSafeArea()
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
                .ignoresSafeArea()
               
                    // Use your FloatingButton implementation unchanged for actions
                    FloatingButton(amplitude: 8, speed: 1.4, action: {
                        // preserved history action exactly as you had previously
                        withAnimation(.easeOut(duration: 0.12)) { logoScale = 0.96 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            withAnimation(.spring()) { logoScale = 1.0 }
                            DispatchQueue.main.async { onShowHistories?() }
                        }
                    }) {
                        Group {
                            if UIImage(named: "higanbana") != nil {
                                // responsive width relative to the full GeometryReader width
                                let imageWidth = max(geo.size.width, 500) // clamp to reasonable range
                                
                                Image("higanbana")
                                    .resizable(capInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    .scaledToFit()
                                    .frame(width: imageWidth, height: imageWidth) // square frame to make positioning predictable
                                    .rotationEffect(Angle(degrees: -45))
                                // place the image so its bottom-right corner aligns with the screen bottom-right
                                // (position uses the GeometryReader's coordinate space)
                                    .position(x: geo.size.width - (imageWidth / 5), y: geo.size.height - (imageWidth / 5))
                                    .allowsHitTesting(false)
                                    .ignoresSafeArea()
                            } else {
                                Color.clear.ignoresSafeArea()
                            }
                        }
                }.ignoresSafeArea()
            }
            VStack(spacing: 24) {
                Spacer().frame(height: 36)

                // Top bar (unchanged)
                HStack {
                    Button(action: { onShowTutorial?() }) {
                        Text("i⃝ Tutorial").bold()
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(6)

                    Spacer()

                    if let user = auth.firebaseUser {
                        Menu {
                            Button(action: { DispatchQueue.main.async { activeSheet = .account } }) { Text("Account") }
                            Button(action: {
                                do { try AuthManager.shared.signOut() } catch { print("DBG: signOut error:", error) }
                            }) { Text("Sign out") }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.circle").font(.title2)
                                Text(firestore.profile?.displayName ?? user.email ?? "Account")
                                    .font(.subheadline).lineLimit(1)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(.systemGray6).opacity(0.3))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        }
                    } else {
                        Button(action: { DispatchQueue.main.async { activeSheet = .signIn } }) {
                            Text("Login")
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibility(identifier: "LoginButton")
                    }
                }
                .padding(.horizontal, 4)

                // Logo
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

                // --- central cluster: precise layout per your sketch ---
                GeometryReader { geo in // 他のものでかなり狭まっているので画面全体のサイズではなく3つのボタンの配置枠くらいのサイズ感
                    let w = geo.size.width
                    let h = geo.size.height
                    let cx = w / 2
                    let cy = h / 2

                    // sizes tuned to your sketch: center diameter = 200
                    let centerSize: CGFloat = min(w, h,300)
                    let leftCrescentSize: CGFloat = 100  // smaller left crescent (history)
                    let rightCrescentSize: CGFloat = 140   // larger right crescent (play)
                    // distance from center for crescent center points so they visually hug the center
                    let leftDistance = centerSize * 0.62
                    let rightDistance = centerSize * 0.78

                    // angles for placement (upper-left / upper-right-ish)
                    let leftAngle = Angle.degrees(-140)   // history small crescent (slightly behind left edge)
                    let rightAngle = Angle.degrees(-40)   // play large crescent (upper-right area)

                    ZStack {
                        // 1) Draw crescents first (they will be visually cut by center)
                        Group {
                            // Left (History) crescent - own VStack
                            VStack {
                                // Use your FloatingButton implementation unchanged for actions
                                FloatingButton(amplitude: 8, speed: 1.4, action: {
                                    // preserved history action exactly as you had previously
                                    withAnimation(.easeOut(duration: 0.12)) { logoScale = 0.96 }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        withAnimation(.spring()) { logoScale = 1.0 }
                                        DispatchQueue.main.async { onShowHistories?() }
                                    }
                                }) {
                                    CrescentView(size: leftCrescentSize,
                                                 innerAngle: Angle.degrees( leftAngle.degrees + 180 ),
                                                 innerOffsetFraction: 0.66,
                                                 innerRadiusRatio: 0.60,
                                                 color: Color.yellow.opacity(0.85)) {
                                        VStack {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 14))
                                            Text("History")
                                                .font(.caption2).bold()
                                        }
                                        .padding(.leading, 2)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .position(x: cx + CGFloat(cos(leftAngle.radians)) * leftDistance,
                                      y: cy + CGFloat(sin(leftAngle.radians)) * leftDistance)

                            // Right (Play) crescent - own VStack
                            VStack {
                                FloatingButton(amplitude: 10, speed: 1.6, action: {
                                    // preserved start action exactly as you provided
                                    withAnimation(.easeOut(duration: 0.12)) { logoScale = 0.96 }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        withAnimation(.spring()) { logoScale = 1.0 }
                                        DispatchQueue.main.async { onStart?() }
                                    }
                                }) {
                                    CrescentView(size: rightCrescentSize,
                                                 innerAngle: Angle.degrees( rightAngle.degrees + 180 ),
                                                 innerOffsetFraction: 0.66,
                                                 innerRadiusRatio: 0.60,
                                                 gradient: LinearGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.95), Color.yellow.opacity(0.75)]), startPoint: .topLeading, endPoint: .bottomTrailing)) {
                                        VStack {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 22))
                                            Text("Play")
                                                .font(.subheadline).bold()
                                        }
                                        .padding(.leading, 6)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .position(x: cx + CGFloat(cos(rightAngle.radians)) * rightDistance,
                                      y: cy + CGFloat(sin(rightAngle.radians)) * rightDistance)
                        }
                        .compositingGroup() // make a group to be affected by destinationOut punch

                        // 2) Punch hole: subtract center circle from crescents so they look cut by center
                        Circle()
                            .frame(width: centerSize, height: centerSize)
                            .position(x: cx, y: cy)
                            .blendMode(.destinationOut)
                            .compositingGroup()

                        // 3) soft shadow under center so center appears above the cut edges
                        Circle()
                            .fill(Color.black.opacity(0.22))
                            .frame(width: centerSize * 1.02, height: centerSize * 1.02)
                            .position(x: cx, y: cy + 8)
                            .blur(radius: 12)
                            .allowsHitTesting(false)

                        // 4) Central split circle (visible on top)
                        VStack {
                            FloatingButton(amplitude: 6, speed: 1.8, action: {
                                // chapters tap preserved (simple)
                                onShowChapters?()
                            }) {
                                ZStack {
                                    SplitCircleView(diameter: centerSize,
                                                    leftColor: Color(red: 0.58, green: 0.18, blue: 0.18),
                                                    rightColor: Color(red: 0.66, green: 0.88, blue: 0.88),
                                                    darkOffsetX: -36,
                                                    blurRadius: 18)
                                    // subtle inner border to suggest the soft boundary sits inside
                                    Circle()
                                        .stroke(Color.white.opacity(0.04), lineWidth: 6)
                                        .frame(width: centerSize - 4, height: centerSize - 4)
                                        .blendMode(.overlay)
                                    VStack {
                                        Image(systemName: "books.vertical.fill").font(.system(size: 26))
                                        Text("Chapters").font(.headline).fontWeight(.semibold)
                                    }
                                }
                                .frame(width: centerSize, height: centerSize)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .position(x: cx, y: cy)
                    }
                    .frame(width: w, height: h)
                }
                .frame(height: 260)

                Spacer()

                // bottom small actions
                HStack(spacing: 12) {
                    Button(action: { onOpenSettings?() }) {
                        Text("Settings")
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: { onShowCredits?() }) {
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

                Text("Version 0.1")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { showSubtitle = true }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .signIn:
                SignInView().ignoresSafeArea(.keyboard, edges: .bottom)
            case .account:
                AccountSettingsView()
            }
        }
        .onChange(of: auth.firebaseUser) { newUser in
            if newUser != nil, activeSheet == .signIn { activeSheet = nil }
        }
    }
}

// MARK: - Preview
struct TitleView_Previews: PreviewProvider {
    static var previews: some View {
        TitleView(onStart: {})
            .preferredColorScheme(.light)
            .previewLayout(.sizeThatFits)
            .frame(width: 800, height: 600)
    }
}
