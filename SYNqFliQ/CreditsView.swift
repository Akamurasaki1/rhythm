//
//  CreditsView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/28.
//　珍しくAIを使わずに構成してるけど、内容の部分とか全部コピペして曲名変えてってやってるの、そこは機械の完全優位分野なんだからなぜ？ってなった()
import SwiftUI

struct CreditsView: View {
    @State private var initialScrollPerformed: Bool = false
    var onShowCredits: () -> Void = { }
    var onClose: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var body: some View {
        ScrollView{
            VStack(alignment: .leading){
                Button(action: { onClose?() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("X︦︦").underline()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading){
                        Text("LeaF").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("Paraclete").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Mere Fancy").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("I").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Resurrection Spell").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Musical Movement").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Exclusive Utopia").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Arianrhod").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("0次元恋愛感情").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("4th smile").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Evanescent").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Poison AND÷OR Affection").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("メルへニア -malchenia-").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                                  Spacer(minLength:10).frame(maxHeight: 50)
                        Text("狂喜蘭舞").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Healing Hurts").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("ATHAZA").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Doppelgenger").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Lyrith -迷宮リリス-").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("MARENOL 1mg").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("MARENOL").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Qual").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("もぺもぺ(2019)").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Calamity Fortune(2019)").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Armageddon").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Wizdomiot(2020)").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Heterochromia Iridis(2020)").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Alice in Misanthrope -厭世アリス-").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Agilion").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Aleph-0(2022)").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("命日").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Verlesq").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("neo tinnitus").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Breakcore WTF").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Link("LeaF:公式ページ",destination: URL(string:"http://leafbms.web.fc2.com/profile.html")!)
                                .font(.footnote).foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    
                    Spacer(minLength: 50)
                    
                    // .padding()
                    //  .background(Color(white: 0.9))
                    VStack(alignment: .leading){
                        Text("Camellia").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Spacer()
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("Body F10ating in the Zero Gravity Space").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("1nput This 2 Y0ur Spine").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Dance with Silence").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Compute It With Some Devilish Alcoholic Steampunk Engines").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Fly Wit Me").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("+ERABY+E CONNEC+10N").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Tera I_O").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("M1LLI0N PP").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Flamewall").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("BAD ACCESS (FROM A MOE MAID)").foregroundColor(.secondary).bold()
                        Text("Album: Tera I/O").font(.caption).foregroundColor(.secondary)
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer()
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Label("Camellia's Page", systemImage: "link")
                                .font(.footnote).foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    Spacer()
                }
                .padding()
                // .background(Color(white: 0.9))
                HStack(alignment: .center) {
                    VStack(alignment: .leading){
                        Text("EBIMAYO").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("GOODMEN").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODTEK").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODBOUNCE").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODRAGE").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODDRILL").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODFORTUNE").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODRUSH").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODRAGE").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("GOODWORDL").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("BADSECRET").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Bad_Cycle").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Power Attack").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Link("EBIMAYO's Page",destination: URL(string:"https://ab-sounds.com/bms/")!)
                                .font(.footnote).foregroundColor(.blue).underline()
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    
                    Spacer(minLength: 50)
                    
                    // .padding()
                    VStack(alignment: .leading){
                        Text("A / Murasaki -Akamurasaki").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Spacer()
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("擬遊戯具 -Psigra Noctis-").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Veritas ataxiΛ").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("Veritas ataxiΛ -Full Version-").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Spacer(minLength:10).frame(maxHeight: 50)
                        Text("NOTITLE...yet").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer()
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Label("Akamurasaki's Page", systemImage: "link")
                                .font(.footnote).foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    
                    Spacer()
                }
                .padding()
                HStack(alignment: .center) {
                    VStack(alignment: .leading){
                        Text("tn-shi").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("Annihilation in F# Minor").foregroundColor(.secondary).bold()
                        Text("BPM: 225 (150 for the first 9 bars)").font(.caption).foregroundColor(.secondary)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Link("tn-shi's YouTube(tn-shi - Annihilation in F# Minor)",destination: URL(string:"https://www.youtube.com/watch?v=eNELszYKqU8")!)
                                .font(.footnote).foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    
                    Spacer(minLength: 50)
                    
                    // .padding()
                    VStack(alignment: .leading){
                        Text("ARForest / #ffffff Records").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Spacer()
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("Forest of Clock").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer()
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Link("ARForest's Linktree",destination: URL(string:"https://linktr.ee/arforest")!)
                                .font(.footnote).foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    
                    Spacer()
                }
                .padding()
                HStack(alignment: .center) {
                    VStack(alignment: .leading){
                        Text("Public Domain Works").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("Lucid Trigger").foregroundColor(.secondary).bold()
                        Text("BPM: ").font(.caption).foregroundColor(.secondary)
                        Link("SoundCloud",destination: URL(string:"https://soundcloud.com/mmry/cc0-lucid-trigger?utm_source=clipboard&utm_campaign=wtshare&utm_medium=widget&utm_content=https%253A%252F%252Fsoundcloud.com%252Fmmry%252Fcc0-lucid-trigger")!).font(.caption).foregroundColor(.secondary).underline()
                        Spacer(minLength: 10).frame(maxHeight: 50)
                        Text("Lunar Arrow").foregroundColor(.secondary).bold()
                        Text("BPM: ").font(.caption).foregroundColor(.secondary)
                        Link("SoundCloud",destination: URL(string:"https://soundcloud.com/mmry/lunar-arrow-edit-0224?utm_source=clipboard&utm_campaign=wtshare&utm_medium=widget&utm_content=https%253A%252F%252Fsoundcloud.com%252Fmmry%252Flunar-arrow-edit-0224")!).font(.caption).foregroundColor(.secondary).underline()
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Link("Public Domainに関するcreative commonsのページ",destination: URL(string:"https://creativecommons.org/publicdomain/mark/1.0/deed.ja")!)
                                .font(.caption).foregroundColor(colorScheme == .light ? .blue : .indigo).underline()
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    
                    Spacer(minLength: 50)
                    
                    // .padding()
                    VStack(alignment: .leading){
                        Text("Neutral Moon").font(.title3.bold()).foregroundStyle(colorScheme == .dark ? .white : .black).shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.9), radius: 5)
                        Spacer()
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Text("モシモシビット(Moshi Moshi Bit)").foregroundColor(.secondary).bold()
                        Text("BPM:").font(.caption).foregroundColor(.secondary)
                        Link("SoundCloud",destination: URL(string:"https://soundcloud.com/neutralmoon/moshi-moshi-bit-neutral-moon?utm_source=clipboard&utm_campaign=wtshare&utm_medium=widget&utm_content=https%253A%252F%252Fsoundcloud.com%252Fneutralmoon%252Fmoshi-moshi-bit-neutral-moon")!).font(.caption).foregroundColor(.secondary).underline()
                        Divider().shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .black.opacity(0.9), radius: 3)
                        Spacer()
                        Spacer(minLength: 10).frame(maxHeight: 15)
                        HStack(spacing: 20) {
                            Link("ARForest's Linktree",destination: URL(string:"https://linktr.ee/arforest")!)
                                .font(.footnote).foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(colorScheme == .light ? .white : .gray.opacity(0.4))
                    .cornerRadius(8)
                    .clipped()
                    .shadow(color: colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.5), radius: 7)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}

// Preview
struct CreditView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsView(onShowCredits:{})
            .preferredColorScheme(.dark)
    }
}
