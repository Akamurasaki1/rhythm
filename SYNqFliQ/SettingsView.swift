//
//  SettingsView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/20.
//

//
//  SettingsView.swift
//  SYNqFliQ
//
//  Created by assistant
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.presentationMode) private var presentationMode

    // Bindings to SettingsStore properties (safe for Slider/value consumers)
    private var approachDistanceFractionBinding: Binding<Double> {
        Binding(get: { settings.approachDistanceFraction },
                set: { settings.approachDistanceFraction = $0 })
    }
    private var approachSpeedBinding: Binding<Double> {
        Binding(get: { settings.approachSpeed },
                set: { settings.approachSpeed = $0 })
    }
    private var holdFillDurationFractionBinding: Binding<Double> {
        Binding(get: { settings.holdFillDurationFraction },
                set: { settings.holdFillDurationFraction = $0 })
    }
    private var holdFinishTrimThresholdBinding: Binding<Double> {
        Binding(get: { settings.holdFinishTrimThreshold },
                set: { settings.holdFinishTrimThreshold = $0 })
    }

    var body: some View {
     /*   VStack(spacing: 8) {
            Text("This is SettingsView")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
        }  */
        NavigationView {
            Form {
                Section(header: Text("Approach (ノーツ出現 / 判定)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "Approach distance fraction: %.2f", settings.approachDistanceFraction))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: approachDistanceFractionBinding, in: 0.05...1.5, step: 0.01)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Approach speed (pts/s): \(Int(settings.approachSpeed))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: approachSpeedBinding, in: 100...3000, step: 1)
                    }
/*                    Spacer()
                    let exampleDistance = settings.approachDistanceFraction * min(geo.size.width, geo.size.height)
                    let derivedDuration = exampleDistance / max(settings.approachSpeed, 1.0)
                    Text("例 dur: \(String(format: "%.2f", derivedDuration))s")
                        .foregroundColor(.gray)
*/
                }

                Section(header: Text("Hold (ホールド)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "Hold fill fraction: %.2f", settings.holdFillDurationFraction))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: holdFillDurationFractionBinding, in: 0.0...2.0, step: 0.01)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "Hold finish trim threshold: %.3f", settings.holdFinishTrimThreshold))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: holdFinishTrimThresholdBinding, in: 0.0...0.5, step: 0.001)
                    }
                }

                Section {
                    Button("Restore defaults") {
                        settings.restoreDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
