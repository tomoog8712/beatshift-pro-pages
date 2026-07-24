import SwiftUI
import StoreKit

enum Theme {
    // Exact tokens from app/index.html :root
    static let bg = Color(hex: 0x0A0A0F)
    static let bgElevated = Color(hex: 0x1C1C24)
    static let surface = Color(hex: 0x1A1A22)
    static let surfaceRaised = Color(hex: 0x22222C)
    static let surfaceHover = Color(hex: 0x2A2A34)
    static let surfaceActive = Color(hex: 0x30303C)
    static let border = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.18)
    static let text = Color(hex: 0xF5F5F7)
    static let textSecondary = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.55)
    static let accent = Color(hex: 0x64D2FF)
    static let accentGlow = Color(hex: 0x64D2FF).opacity(0.35)
    static let accentPurple = Color(hex: 0xBF5AF2)
    static let accentOrange = Color(hex: 0xFF9F0A)
    static let accentTeal = Color(hex: 0x5AC8FA)
    static let accentPink = Color(hex: 0xFF375F)
    static let accentGreen = Color(hex: 0x30D158)
    static let minus = Color(hex: 0xE74C3C)
    static let plus = Color(hex: 0x3498DB)
    static let dialOrange = Color(hex: 0xF39C12)
    static let dialOrangeDeep = Color(hex: 0xD35400)
    static let radiusMD: CGFloat = 14
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

struct MainView: View {
    @StateObject private var store = BeatShiftStore()
    @StateObject private var reviewPrompt = AppReviewPromptController()
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            // Match HTML radial gradients
            RadialGradient(
                colors: [Theme.accent.opacity(0.12), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Theme.accentPurple.opacity(0.08), .clear],
                center: UnitPoint(x: 1.0, y: 1.05),
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        topBar
                        tabs
                        hero
                        if store.mode == .normal || store.mode == .modulation || store.mode == .oddTime {
                            swingSlider
                        }
                        controls
                        modePanel
                            .frame(minHeight: 320)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity)
                }

                if reviewPrompt.isBannerVisible {
                    AppReviewBannerView(
                        onRate: {
                            requestReview()
                            reviewPrompt.dismissPermanently()
                        },
                        onDismiss: {
                            reviewPrompt.dismissPermanently()
                        }
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.28), value: reviewPrompt.isBannerVisible)
        .sheet(item: $store.modal) { kind in
            ModalSheet(kind: kind, store: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .beatshiftWillBackground)) { _ in
            store.handleBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: .beatshiftDidForeground)) { _ in
            store.handleForeground()
            reviewPrompt.scheduleIfNeeded()
        }
        .onReceive(store.objectWillChange) { _ in
            DispatchQueue.main.async {
                store.syncEngineConfig()
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text("BeatShift")
                .font(.system(size: 14, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(
                    LinearGradient(colors: [.white, Theme.textSecondary], startPoint: .top, endPoint: .bottom)
                )
            HStack(spacing: 6) {
                Text(store.l10n.modeNames[store.mode.tabIndex])
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(tabColor(store.mode.tabIndex))
                    .frame(minWidth: 90, alignment: .leading)
                Spacer()
                Button {
                    store.modal = .setlist
                } label: {
                    Text("💾")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Theme.surface)
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        .clipShape(Capsule())
                }
                .accessibilityLabel("再生リスト")
            }
        }
        .frame(height: 30)
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                let titles = ["SEQ", "C.UP", "SPD", "ODD", "MOD"]
                Button {
                    store.switchMode(i)
                } label: {
                    Text(titles[i])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(store.mode.tabIndex == i ? tabColor(i) : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(store.mode.tabIndex == i ? Theme.surfaceActive : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(store.mode.tabIndex == i ? Theme.borderStrong : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
        }
        .padding(6)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMD).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }

    private func tabColor(_ i: Int) -> Color {
        switch i {
        case 0: return Theme.accent
        case 1: return Theme.accentPink
        case 2: return Theme.accentPurple
        case 3: return Theme.accentOrange
        default: return Theme.accentTeal
        }
    }

    private var hero: some View {
        HStack {
            if store.mode != .oddTime {
                beatRing
            }
            Group {
                if store.mode == .oddTime {
                    oddHero
                } else {
                    normalHero
                }
            }
            .frame(maxWidth: .infinity)
            if store.mode != .oddTime {
                pendulum
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(minHeight: store.mode == .oddTime ? 158 : 126)
        .background(HardwarePanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }

    private var oddHero: some View {
        VStack(spacing: 8) {
            Text("\(store.bpm)")
                .font(.system(size: 52, weight: .bold))
                .tracking(-1.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color.white.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            FlexibleOddDots(store: store)
        }
    }

    private var beatRing: some View {
        ZStack {
            Circle()
                .stroke(store.ringFlash ? Theme.accent : Color.white.opacity(0.12), lineWidth: 2)
                .frame(width: 32, height: 32)
                .shadow(color: store.ringFlash ? Theme.accentGlow : .clear, radius: 10)
            Circle()
                .fill(store.ringFlash ? Theme.accent : Color.white.opacity(0.2))
                .frame(width: store.ringFlash ? 10 : 8, height: store.ringFlash ? 10 : 8)
        }
        .frame(width: 40)
    }

    private var pendulum: some View {
        Rectangle()
            .fill(
                LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.2)], startPoint: .bottom, endPoint: .top)
            )
            .frame(width: 2, height: 22)
            .shadow(color: Theme.accentGlow, radius: 6)
            .rotationEffect(.degrees(Double(store.pendulumSign) * 22), anchor: .bottom)
            .animation(.easeOut(duration: 0.06), value: store.pendulumSign)
            .frame(width: 40, height: 28, alignment: .bottom)
    }

    private var normalHero: some View {
        VStack(spacing: 4) {
            if store.mode == .normal {
                Picker("", selection: Binding(
                    get: { store.totalBeatsInBar },
                    set: { store.changeTimeSignature($0) }
                )) {
                    ForEach([2, 3, 4, 5, 6], id: \.self) { n in
                        Text("\(n) / 4").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 10, weight: .bold))
                .tint(Theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Theme.surfaceRaised)
                .overlay(Capsule().stroke(Theme.borderStrong, lineWidth: 1))
                .clipShape(Capsule())
            }

            HStack(spacing: 0) {
                Button("-10") { store.adjustBpmSkip(-10) }
                    .buttonStyle(BpmSkipStyle(color: Theme.minus))
                Spacer(minLength: 12)
                VStack(spacing: 0) {
                    Text(store.heroLabel.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.accent)
                    Text("\(store.bpm)")
                        .font(.system(size: 44, weight: .bold))
                        .tracking(-1.5)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.72)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                Spacer(minLength: 12)
                Button("+10") { store.adjustBpmSkip(10) }
                    .buttonStyle(BpmSkipStyle(color: Theme.plus))
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                let count = store.mode == .speed ? 4 : store.totalBeatsInBar
                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(store.activeBeat == i ? Theme.accent : Color.white.opacity(0.15))
                        .frame(width: 5, height: 5)
                        .shadow(color: store.activeBeat == i ? Theme.accentGlow : .clear, radius: 4)
                        .scaleEffect(store.activeBeat == i ? 1.25 : 1)
                }
            }
        }
    }

    private var swingSlider: some View {
        let pct = Int((store.swingRatio * 100).rounded())
        let suffix = pct == 66 ? " (Shuffle)" : (pct == 75 ? " (Swing)" : "")
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(store.l10n.swingTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(pct)%\(suffix)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            GeometryReader { geo in
                let trackW = geo.size.width
                let knobW: CGFloat = 36
                let travel = max(trackW - knobW, 1)
                let t = (store.swingRatio - 0.5) / 0.35
                let x = CGFloat(t) * travel

                ZStack(alignment: .leading) {
                    // Recessed track — no blue fill
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

                    MetalFaderKnob(width: knobW, height: 20, verticalLine: true)
                        .offset(x: x)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let nx = min(max(0, drag.location.x - knobW / 2), travel)
                            let ratio = 0.5 + 0.35 * Double(nx / travel)
                            store.swingRatio = ratio
                        }
                )
                .disabled(store.modSwingType() == .disabled)
                .opacity(store.modSwingType() == .disabled ? 0.35 : 1)
            }
            .frame(height: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(HardwarePanelBackground())
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(spacing: 6) {
                controlBtn("TAP", color: Theme.accent) { store.tapTempo() }
                if store.mode == .changeUp {
                    Button {
                        store.modal = .bars
                    } label: {
                        HStack(spacing: 4) {
                            Text("⇄").foregroundStyle(Theme.accent)
                            Text(store.cuProgressText)
                                .foregroundStyle(Theme.accent)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.12), Theme.accent.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Text(store.cuNoteText)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(store.isRunning ? Color(hex: 0xFF6B9D) : Theme.accentPink)
                        .shadow(color: Theme.accentPink.opacity(store.isRunning ? 0.55 : 0.35), radius: store.isRunning ? 12 : 8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                }
                if store.mode == .normal || store.mode == .modulation || store.mode == .oddTime {
                    controlBtn(store.swingButtonTitle, color: store.swingMode == .off ? Theme.textSecondary : Theme.plus) {
                        store.toggleSwing()
                    }
                    .opacity(store.modSwingType() == .disabled ? 0.35 : 1)
                    .disabled(store.modSwingType() == .disabled)
                }
                if store.mode == .normal || store.mode == .oddTime {
                    controlBtn(store.soundButtonTitle, color: Theme.text) { store.modal = .sound }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 158)

            TempoDialView(store: store)
        }
    }

    private func controlBtn(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .frame(height: store.mode == .changeUp ? 36 : 44)
                .background(Theme.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            color == Theme.accent ? Theme.accent.opacity(0.25) : Theme.border,
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var modePanel: some View {
        switch store.mode {
        case .normal:
            NormalMixerPanel(store: store)
        case .changeUp:
            ChangeUpPanel(store: store)
        case .speed:
            SpeedPanel(store: store)
        case .oddTime:
            OddTimePanel(store: store)
        case .modulation:
            ModulationPanel(store: store)
        }
    }
}

struct BpmSkipStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 44, height: 36)
            .background(Theme.surfaceRaised)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct FlexibleOddDots: View {
    @ObservedObject var store: BeatShiftStore
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 44), spacing: 6)]
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<store.oddNumerator, id: \.self) { i in
                let on = (store.oddPatterns[safe: i] ?? 0) != 0
                let flash = store.oddFlashStep == i
                Button {
                    store.toggleOddPattern(i)
                } label: {
                    Text(on ? "●" : "○")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(on ? Theme.accentOrange : Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(flash ? Theme.accentOrange.opacity(0.25) : Theme.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(flash ? Theme.accentOrange : Theme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .scaleEffect(flash ? 1.25 : 1)
                        .shadow(color: flash ? Theme.accentOrange.opacity(0.5) : .clear, radius: 8)
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
