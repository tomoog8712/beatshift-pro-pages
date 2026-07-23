import SwiftUI

// MARK: - Shared hardware chrome

struct HardwarePanelBackground: View {
    var cornerRadius: CGFloat = Theme.radiusMD
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x22222C), Color(hex: 0x1E1E26), Color(hex: 0x1A1A22)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    .blur(radius: 0.5)
                    .padding(1)
                    .allowsHitTesting(false)
            )
    }
}

struct MetalFaderKnob: View {
    var width: CGFloat = 38
    var height: CGFloat = 18
    var verticalLine: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xECECF0),
                            Color(hex: 0xE5E5EA),
                            Color(hex: 0xD1D1D6),
                            Color(hex: 0xB8B8BE),
                            Color(hex: 0xA8A8AD)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(hex: 0x999999), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.5), radius: 2.5, y: 2)
                .overlay(alignment: .top) {
                    // Highlight strip
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(height: 1)
                        .padding(.horizontal, 2)
                        .padding(.top, 1)
                }

            if verticalLine {
                Rectangle()
                    .fill(Color(hex: 0x666666))
                    .frame(width: 2, height: height - 6)
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .frame(height: 2)
                    .padding(.horizontal, 5)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Tempo dial (BOSS DB-90 style)

struct TempoDialView: View {
    @ObservedObject var store: BeatShiftStore
    @State private var lastAngle: Double?
    @State private var rotation: Double = 0

    private let size: CGFloat = 150
    private let faceInset: CGFloat = 5
    private let centerSize: CGFloat = 90

    var body: some View {
        ZStack {
            // Knurled outer ring (repeating conic #c06500 / #f39c12)
            Canvas { context, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let radius = min(sz.width, sz.height) / 2
                let segments = 75 // 360 / 4.8
                for i in 0..<segments {
                    let start = Angle.degrees(Double(i) * 4.8 - 3)
                    let mid = Angle.degrees(Double(i) * 4.8 - 3 + 2.4)
                    let end = Angle.degrees(Double(i) * 4.8 - 3 + 4.8)
                    var dark = Path()
                    dark.addArc(center: center, radius: radius, startAngle: start, endAngle: mid, clockwise: false)
                    dark.addLine(to: center)
                    dark.closeSubpath()
                    context.fill(dark, with: .color(Color(hex: 0xC06500)))
                    var light = Path()
                    light.addArc(center: center, radius: radius, startAngle: mid, endAngle: end, clockwise: false)
                    light.addLine(to: center)
                    light.closeSubpath()
                    context.fill(light, with: .color(Color(hex: 0xF39C12)))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.45), radius: 7, y: 5)

            // Orange face — flat solid (no gradient)
            Circle()
                .fill(Color(hex: 0xF39C12))
                .frame(width: size - faceInset * 2, height: size - faceInset * 2)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .rotationEffect(.degrees(rotation))

            // Tick marks around face (dark orange radial lines)
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 140 / 255, green: 50 / 255, blue: 0).opacity(0.85))
                    .frame(width: 1.5, height: 7)
                    .offset(y: -(size / 2 - faceInset - 12))
                    .rotationEffect(.degrees(Double(i) * 30 + 15 + rotation))
            }
            .allowsHitTesting(false)

            // Dimple (recessed pock)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: 0xFFC364).opacity(0.3),
                                Color(hex: 0x823700).opacity(0.42),
                                Color(hex: 0x501E00).opacity(0.52)
                            ],
                            center: UnitPoint(x: 0.42, y: 0.38),
                            startRadius: 1,
                            endRadius: 9
                        )
                    )
                // Inset shadow simulation
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color(hex: 0xFFD282).opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .frame(width: 16, height: 16)
            .offset(y: -54)
            .rotationEffect(.degrees(rotation))
            .allowsHitTesting(false)

            // Inner bezel shadow ring
            Circle()
                .stroke(Color.black.opacity(0.45), lineWidth: 2)
                .frame(width: size - 60, height: size - 60)
                .shadow(color: .black.opacity(0.35), radius: 5)
                .allowsHitTesting(false)

            // Center START / STOP — deep green (HTML exact)
            Button {
                store.togglePlay()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            store.isRunning
                                ? LinearGradient(
                                    colors: [Color(hex: 0x5DFFA0), Color(hex: 0x2ECC71), Color(hex: 0x27AE60)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [Color(hex: 0x1F6B3A), Color(hex: 0x0D3D1F), Color(hex: 0x082A15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    store.isRunning
                                        ? Color(hex: 0x78FFB4).opacity(0.7)
                                        : Color.black.opacity(0.38),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .black.opacity(0.42), radius: 6, y: 3)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Color.white.opacity(store.isRunning ? 0.35 : 0.12))
                                .frame(width: 50, height: 8)
                                .blur(radius: 4)
                                .offset(y: 10)
                        }
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(Color.black.opacity(0.45))
                                .frame(width: 56, height: 12)
                                .blur(radius: 5)
                                .offset(y: -8)
                        }

                    Text(store.isRunning ? "STOP" : "START")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(.white)
                        .shadow(
                            color: store.isRunning ? .white.opacity(0.65) : .black.opacity(0.45),
                            radius: store.isRunning ? 5 : 2,
                            y: 1
                        )
                }
                .frame(width: centerSize, height: centerSize)
                .shadow(
                    color: store.isRunning ? Color(hex: 0x2ECC71).opacity(0.75) : .clear,
                    radius: store.isRunning ? 14 : 0
                )
            }
            .buttonStyle(.plain)
        }
        .frame(width: size, height: size)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let center = CGPoint(x: size / 2, y: size / 2)
                    let angle = atan2(value.location.y - center.y, value.location.x - center.x) * 180 / .pi
                    if let last = lastAngle {
                        var delta = angle - last
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }
                        rotation += delta
                        store.applyDialDelta(degrees: delta)
                    } else {
                        store.prepareDialHaptic()
                    }
                    lastAngle = angle
                }
                .onEnded { _ in lastAngle = nil }
        )
    }
}

// MARK: - Mixer faders

struct NormalMixerPanel: View {
    @ObservedObject var store: BeatShiftStore

    private let iconColor = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255).opacity(0.88)

    var body: some View {
        HStack(spacing: 6) {
            mixerCol("AC", value: $store.accentVol) {
                Text("A")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(height: 38)
            }
            mixerCol("4分", value: $store.quarterVol) {
                Image("MixerQuarter")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(height: 28)
                    .foregroundStyle(iconColor)
                    .frame(height: 38, alignment: .bottom)
            }
            mixerCol("8分", value: $store.eighthVol) {
                HStack(alignment: .center, spacing: -1) {
                    Image("MixerEighthRest")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 13)
                    Image("MixerEighthNote")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 28)
                }
                .foregroundStyle(iconColor)
                .frame(height: 38, alignment: .bottom)
            }
            mixerCol("16分", value: $store.sixteenthVol) {
                HStack(alignment: .center, spacing: -7) {
                    Image("MixerSixteenthRest")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 13)
                    Image("MixerSixteenthNote")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 28)
                    Image("MixerSixteenthRest")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 13)
                    Image("MixerSixteenthNote")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 28)
                }
                .foregroundStyle(iconColor)
                .frame(height: 38, alignment: .bottom)
            }
            mixerCol("3連", value: $store.tripletVol) {
                Image("MixerTriplet")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(height: 30)
                    .foregroundStyle(iconColor)
                    .frame(height: 38, alignment: .bottom)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x2E2E38), Color(hex: 0x26262F), Color(hex: 0x22222C)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
        .padding(6)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x22222C), Color(hex: 0x1E1E26), Color(hex: 0x1A1A22)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
    }

    private func mixerCol<Icon: View>(_ label: String, value: Binding<Double>, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 6) {
            Text("\(Int((value.wrappedValue * 100).rounded()))")
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(Color(hex: 0xFFBF5A))
                .shadow(color: .black.opacity(0.6), radius: 1, y: 1)

            GeometryReader { geo in
                let trackH = geo.size.height
                let travel = max(trackH - 18, 1)
                let knobY = (1 - value.wrappedValue) * travel
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0x14141C))
                        .frame(width: 5)
                        .padding(.vertical, 10)
                        .shadow(color: .black.opacity(0.75), radius: 2.5, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.black.opacity(0.6), lineWidth: 0.5)
                                .padding(.vertical, 10)
                        )

                    MetalFaderKnob(width: 38, height: 18)
                        .offset(y: knobY - (trackH / 2 - 9))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let y = min(max(0, drag.location.y - 9), travel)
                            value.wrappedValue = 1 - (y / travel)
                        }
                )
            }
            .frame(height: 120)

            icon()
                .frame(maxWidth: .infinity)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Other mode panels (unchanged structure, hardware chrome)

struct ChangeUpPanel: View {
    @ObservedObject var store: BeatShiftStore

    var body: some View {
        VStack(spacing: 8) {
            directionBar(current: store.cuDirection, set: { store.cuDirection = $0 })
            volRow(store.l10n.cuMxGuide, value: $store.cuVolGuide)
            volRow(store.l10n.cuMxPulse, value: $store.cuVolPulse)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(RhythmType.cuSequence.indices, id: \.self) { i in
                    let note = RhythmType.cuSequence[i]
                    let selected = store.cuSelectedFlags[safe: i] == true
                    Button {
                        store.toggleCuFlag(at: i)
                    } label: {
                        Text(store.l10n.notes[note] ?? note)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(selected ? .white : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selected ? Theme.accentPink.opacity(0.35) : Theme.surfaceRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selected ? Theme.accentPink : Theme.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HardwarePanelBackground())
    }
}

struct SpeedPanel: View {
    @ObservedObject var store: BeatShiftStore

    var body: some View {
        VStack(spacing: 8) {
            directionBar(current: store.spdDirection) { dir in
                store.spdDirection = dir
                if !store.isRunning { store.syncSpeedBpmDisplay() }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                optBox(store.l10n.spdStart, "\(store.spdStartBpm) BPM", Theme.accentPink) { store.modal = .speedBpm(true) }
                optBox(store.l10n.spdEnd, "\(store.spdEndBpm) BPM", Theme.accentPurple) { store.modal = .speedBpm(false) }
                optBox(store.l10n.spdSec, formatSec(store.spdStepSec), Theme.accentOrange) { store.modal = .speedPace(true) }
                optBox(store.l10n.spdVal, "\(store.spdStepBpm) BPM", Theme.accent) { store.modal = .speedPace(false) }
            }
            Button {
                store.modal = .speedRhythm
            } label: {
                let key = RhythmType.spdRhythmPool[safe: store.spdRhythmIndex] ?? "16分音符"
                Text("\(store.l10n.lblCount)\(store.l10n.notes[key] ?? key)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            volRow(store.l10n.cuMxGuide, value: $store.spdVolGuide)
            volRow("② COUNT", value: $store.spdVolPulse)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HardwarePanelBackground())
    }

    private func formatSec(_ v: Double) -> String {
        v == floor(v) ? "\(Int(v)) 秒" : String(format: "%.1f 秒", v)
    }

    private func optBox(_ title: String, _ value: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Theme.surfaceRaised)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct OddTimePanel: View {
    @ObservedObject var store: BeatShiftStore
    var body: some View {
        Button {
            store.modal = .oddSig
        } label: {
            Text("\(store.l10n.lblOddSigSetting)\(store.oddSignatureKey) ⚙️")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.surfaceRaised)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HardwarePanelBackground())
    }
}

struct ModulationPanel: View {
    @ObservedObject var store: BeatShiftStore
    var body: some View {
        VStack(spacing: 8) {
            Button {
                store.modal = .modMatrix
            } label: {
                let key = RhythmType.modMatrixPool[safe: store.modMatrixIndex] ?? ""
                Text("A: \(store.l10n.notes[key] ?? key)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.surfaceRaised)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: 6) {
                Button {
                    store.modTrainingEnabled.toggle()
                } label: {
                    Text(store.modTrainingEnabled ? store.l10n.modTrainOn : store.l10n.modTrainOff)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(store.modTrainingEnabled ? Theme.accentGreen : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button {
                    store.modal = .modCycle
                } label: {
                    Text("\(store.modTrainingCycleBars) \(store.l10n.modCycleUnit)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            volRow(store.l10n.modLabelGuide, value: $store.modVolGuide)
            volRow(store.l10n.modLabelAccent, value: $store.modVolAccent)
            volRow(store.l10n.modLabelNormal, value: $store.modVolNormal)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HardwarePanelBackground())
    }
}

func directionBar(current: DirectionMode, set: @escaping (DirectionMode) -> Void) -> some View {
    HStack(spacing: 6) {
        ForEach([(DirectionMode.fwd, "→"), (.rev, "←"), (.bounce, "←→")], id: \.0.rawValue) { item in
            Button {
                set(item.0)
            } label: {
                Text(item.1)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(current == item.0 ? Theme.accent : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(current == item.0 ? Theme.surfaceActive : Theme.surfaceRaised)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

func volRow(_ title: String, value: Binding<Double>) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: 100, alignment: .leading)
        Slider(value: value, in: 0...1).tint(Theme.accent)
        Text("\(Int((value.wrappedValue * 100).rounded()))%")
            .font(.system(size: 11, weight: .bold).monospacedDigit())
            .foregroundStyle(Theme.text)
            .frame(width: 40, alignment: .trailing)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
