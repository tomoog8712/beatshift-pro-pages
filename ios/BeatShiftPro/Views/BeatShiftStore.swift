import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class BeatShiftStore: ObservableObject {
    let engine = MetronomeEngine()
    private let setlistStore = SetlistStore()

    @Published var lang: AppLang = .detect()
    @Published var mode: AppMode = .normal
    @Published var bpm: Int = 120
    @Published var soundType: SoundType = .click
    @Published var isRunning = false
    @Published var heroLabel = "Tempo"

    @Published var swingMode: SwingMode = .off
    @Published var swingRatio: Double = 0.666
    @Published var totalBeatsInBar = 4

    @Published var accentVol = 1.0
    @Published var quarterVol = 1.0
    @Published var eighthVol = 0.0
    @Published var sixteenthVol = 0.0
    @Published var tripletVol = 0.0

    @Published var activeBeat = -1
    @Published var pendulumSign = 1
    @Published var ringFlash = false
    @Published var oddFlashStep = -1

    @Published var cuVolGuide = 0.50
    @Published var cuVolPulse = 0.90
    @Published var cuSelectedFlags: [Bool] = [
        false, false, false, true, false, true, false, true, false, false, true, false, true, false, false
    ]
    @Published var cuActiveQueue: [String] = ["4分音符", "2拍3連", "8分音符", "3連符", "16分音符"]
    @Published var cuDirection: DirectionMode = .fwd
    @Published var maxBarsPerPattern = 2
    @Published var cuNoteText = "4分音符"
    @Published var cuProgressText = "1 小節 / 2 小節"

    @Published var spdStartBpm = 20
    @Published var spdEndBpm = 160
    @Published var spdStepSec = 0.2
    @Published var spdStepBpm = 1
    @Published var spdDirection: DirectionMode = .fwd
    @Published var spdVolGuide = 0.85
    @Published var spdVolPulse = 1.0
    @Published var spdRhythmIndex = 4

    @Published var oddSignatureKey = "7/8"
    @Published var oddNumerator = 7
    @Published var oddDenominator = 8
    @Published var oddPatterns: [Int] = [1, 0, 0, 1, 0, 0, 0]
    @Published var oddVol = 1.0

    @Published var modMatrixIndex = 2
    @Published var modVolGuide = 1.0
    @Published var modVolAccent = 0.85
    @Published var modVolNormal = 0.50
    @Published var modTrainingEnabled = false
    @Published var modTrainingCycleBars = 2

    @Published var setlist: [SetlistItem] = []
    @Published var modal: ModalKind?
    @Published var saveNameDraft = ""

    private var modeSettings: [AppMode: ModeSettings] = [
        .normal: ModeSettings(bpm: 120, soundType: .click),
        .changeUp: ModeSettings(bpm: 120, soundType: .click),
        .speed: ModeSettings(bpm: 20, soundType: .click),
        .oddTime: ModeSettings(bpm: 120, soundType: .click),
        .modulation: ModeSettings(bpm: 120, soundType: .click)
    ]

    private var lastTap: Date?
    private var tapIntervals: [Double] = []
    private var dialBpmAccum: Double = 120
    private let dialHaptic = UISelectionFeedbackGenerator()

    nonisolated(unsafe) private var snapLangIsJP = true
    nonisolated(unsafe) private var snapNotes: [String: String] = [:]
    nonisolated(unsafe) private var snapBarsUnit = "Bars"
    nonisolated(unsafe) private var snapBarProgress = "Bars"

    var l10n: L10nStrings { L10n.strings(for: lang) }

    enum ModalKind: Identifiable, Equatable {
        case sound, bars, setlist, savePrompt, settings
        case speedBpm(Bool) // true = start
        case speedPace(Bool) // true = sec
        case speedRhythm
        case oddSig
        case modMatrix
        case modCycle
        var id: String {
            switch self {
            case .sound: return "sound"
            case .bars: return "bars"
            case .setlist: return "setlist"
            case .savePrompt: return "save"
            case .settings: return "settings"
            case .speedBpm(let s): return s ? "spdStart" : "spdEnd"
            case .speedPace(let s): return s ? "spdSec" : "spdBpm"
            case .speedRhythm: return "spdRhythm"
            case .oddSig: return "odd"
            case .modMatrix: return "mod"
            case .modCycle: return "cycle"
            }
        }
    }

    init() {
        setlist = setlistStore.load()
        applyOddPreset("7/8")
        refreshLocaleSnapshot()
        refreshCuLabels()
        engine.delegate = self
        syncEngineConfig()
        BackgroundAudioKeeper.shared.configureRemoteCommands(
            play: { [weak self] in Task { @MainActor in self?.start() } },
            pause: { [weak self] in Task { @MainActor in self?.stop() } }
        )
    }

    func syncEngineConfig() {
        engine.updateSharedConfig(makeConfig())
    }

    func refreshLocaleSnapshot() {
        let s = l10n
        snapLangIsJP = lang == .jp
        snapNotes = s.notes
        snapBarsUnit = s.barsUnit
        snapBarProgress = s.barProgress
    }

    func makeConfig() -> MetronomeConfig {
        MetronomeConfig(
            mode: mode,
            bpm: bpm,
            soundType: soundType,
            swingMode: swingMode,
            swingRatio: swingRatio,
            totalBeatsInBar: totalBeatsInBar,
            accentVol: accentVol,
            quarterVol: quarterVol,
            eighthVol: eighthVol,
            sixteenthVol: sixteenthVol,
            tripletVol: tripletVol,
            cuVolGuide: cuVolGuide,
            cuVolPulse: cuVolPulse,
            cuActiveQueue: cuActiveQueue.isEmpty ? ["4分音符"] : cuActiveQueue,
            cuDirection: cuDirection,
            maxBarsPerPattern: maxBarsPerPattern,
            spdStartBpm: spdStartBpm,
            spdEndBpm: spdEndBpm,
            spdStepSec: spdStepSec,
            spdStepBpm: spdStepBpm,
            spdDirection: spdDirection,
            spdVolGuide: spdVolGuide,
            spdVolPulse: spdVolPulse,
            spdRhythmIndex: spdRhythmIndex,
            oddNumerator: oddNumerator,
            oddDenominator: oddDenominator,
            oddPatterns: oddPatterns,
            oddVol: oddVol,
            modMatrixIndex: modMatrixIndex,
            modVolGuide: modVolGuide,
            modVolAccent: modVolAccent,
            modVolNormal: modVolNormal,
            modTrainingEnabled: modTrainingEnabled,
            modTrainingCycleBars: modTrainingCycleBars
        )
    }

    func togglePlay() {
        if isRunning { stop() } else { start() }
    }

    func start() {
        syncEngineConfig()
        engine.ensureStarted()
        isRunning = true
        heroLabel = "Tempo"
        BackgroundAudioKeeper.shared.setMetronomeRunning(true)
        engine.start()
    }

    func stop() {
        engine.stop()
        isRunning = false
        activeBeat = -1
        oddFlashStep = -1
        ringFlash = false
        heroLabel = "Tempo"
        BackgroundAudioKeeper.shared.setMetronomeRunning(false)
        if mode == .speed { syncSpeedBpmDisplay() }
        refreshCuLabels()
    }

    func switchMode(_ index: Int) {
        stop()
        modeSettings[mode] = ModeSettings(bpm: bpm, soundType: soundType)
        mode = AppMode.from(index: index)
        if let s = modeSettings[mode] {
            bpm = s.bpm
            soundType = s.soundType
            dialBpmAccum = Double(bpm)
        }
        switch mode {
        case .normal:
            break
        case .changeUp, .speed:
            totalBeatsInBar = 4
        case .oddTime:
            break
        case .modulation:
            applyModSwingConstraints()
        }
        if mode == .speed { syncSpeedBpmDisplay() }
        refreshCuLabels()
        syncEngineConfig()
    }

    func updateBPM(_ value: Int, fromDial: Bool = false) {
        let limits = bpmLimits
        bpm = min(limits.max, max(limits.min, value))
        modeSettings[mode]?.bpm = bpm
        if !fromDial { dialBpmAccum = Double(bpm) }
        else if bpm == limits.min || bpm == limits.max { dialBpmAccum = Double(bpm) }
        syncEngineConfig()
    }

    var bpmLimits: (min: Int, max: Int) {
        switch mode {
        case .normal:
            return (AppConstants.seqBpmMin, AppConstants.seqBpmMax)
        case .speed:
            return (AppConstants.spdBpmMin, AppConstants.bpmMax)
        default:
            return (AppConstants.bpmMin, AppConstants.bpmMax)
        }
    }

    func adjustBpmSkip(_ delta: Int) {
        updateBPM(bpm + delta)
    }

    func tapTempo() {
        let now = Date()
        if let last = lastTap {
            let dt = now.timeIntervalSince(last)
            if dt > 0.2 && dt < 2.0 {
                tapIntervals.append(dt)
                if tapIntervals.count > 5 { tapIntervals.removeFirst() }
                let avg = tapIntervals.reduce(0, +) / Double(tapIntervals.count)
                let cal = Int((60.0 / avg).rounded())
                let limits = bpmLimits
                updateBPM(min(limits.max, max(limits.min, cal)))
            }
        }
        lastTap = now
    }

    func applyDialDelta(degrees: Double) {
        let previous = bpm
        dialBpmAccum += degrees * AppConstants.bpmPerDegree
        updateBPM(Int(dialBpmAccum.rounded()), fromDial: true)
        if bpm != previous {
            // ダイヤルの「カチカチ」感。Taptic Engine（着信マナーとは独立して動作）
            dialHaptic.selectionChanged()
            dialHaptic.prepare()
        }
    }

    func prepareDialHaptic() {
        dialHaptic.prepare()
    }

    func toggleSwing() {
        if mode == .modulation {
            let modSwing = modSwingType()
            if modSwing == .disabled { return }
            if modSwing == .eighthOnly {
                swingMode = swingMode == .eighth ? .off : .eighth
            } else if modSwing == .sixteenthOnly {
                swingMode = swingMode == .sixteenth ? .off : .sixteenth
            }
            return
        }
        switch swingMode {
        case .off: swingMode = .eighth
        case .eighth: swingMode = .sixteenth
        case .sixteenth: swingMode = .off
        }
    }

    enum ModSwingConstraint { case disabled, eighthOnly, sixteenthOnly, none }

    func modSwingType() -> ModSwingConstraint {
        guard mode == .modulation else { return .none }
        let t = RhythmType.modMatrixPool[safe: modMatrixIndex] ?? ""
        if t.hasPrefix("3連") { return .disabled }
        if t.contains("16分") { return .sixteenthOnly }
        if t.contains("8分") { return .eighthOnly }
        return .none
    }

    func applyModSwingConstraints() {
        switch modSwingType() {
        case .disabled:
            swingMode = .off
        case .eighthOnly where swingMode == .sixteenth:
            swingMode = .off
        case .sixteenthOnly where swingMode == .eighth:
            swingMode = .off
        default:
            break
        }
    }

    var swingButtonTitle: String {
        if modSwingType() == .disabled { return l10n.swingBtnOff }
        switch swingMode {
        case .eighth: return l10n.swingBtn8th
        case .sixteenth: return l10n.swingBtn16th
        case .off: return l10n.swingBtnOff
        }
    }

    var soundButtonTitle: String {
        switch soundType {
        case .click: return l10n.soundClick
        case .woodblock: return l10n.soundWoodblock
        case .voice: return l10n.soundVoice
        }
    }

    func changeTimeSignature(_ beats: Int) {
        totalBeatsInBar = beats
    }

    func toggleCuFlag(at index: Int) {
        guard RhythmType.cuSequence.indices.contains(index) else { return }
        cuSelectedFlags[index].toggle()
        cuActiveQueue = zip(RhythmType.cuSequence, cuSelectedFlags).compactMap { $1 ? $0 : nil }
        if cuActiveQueue.isEmpty {
            cuSelectedFlags[3] = true
            cuActiveQueue = ["4分音符"]
        }
        refreshCuLabels()
    }

    func refreshCuLabels() {
        let active = cuActiveQueue.first ?? "4分音符"
        cuNoteText = l10n.notes[active] ?? active
        cuProgressText = "1 \(l10n.barProgress) / \(maxBarsPerPattern) \(l10n.barsUnit)"
    }

    func applyOddPreset(_ key: String) {
        oddSignatureKey = key
        if let p = RhythmType.oddPresets[key] {
            oddNumerator = p.num
            oddDenominator = p.den
            oddPatterns = p.pat
        }
    }

    func toggleOddPattern(_ index: Int) {
        guard oddPatterns.indices.contains(index) else { return }
        oddPatterns[index] = oddPatterns[index] == 0 ? 1 : 0
    }

    func syncSpeedBpmDisplay() {
        bpm = spdDirection == .rev ? spdEndBpm : spdStartBpm
        dialBpmAccum = Double(bpm)
    }

    func saveCurrentConfig(name: String) {
        stop()
        var item = SetlistItem(name: name, bpm: bpm, mode: mode.rawValue, timeSignature: totalBeatsInBar)
        switch mode {
        case .normal:
            item.swingMode = swingMode.rawValue
            item.swingRatio = swingRatio
            item.mixerAccent = accentVol * 100
            item.mixerQuarter = quarterVol * 100
            item.mixerEighth = eighthVol * 100
            item.mixerSixteenth = sixteenthVol * 100
            item.mixerTriplet = tripletVol * 100
        case .changeUp:
            item.cuSelectedFlags = cuSelectedFlags
            item.cuActiveQueue = cuActiveQueue
            item.maxBarsPerPattern = maxBarsPerPattern
            item.cuVolGuide = cuVolGuide
            item.cuVolPulse = cuVolPulse
            item.cuDirection = cuDirection.rawValue
        case .speed:
            item.spdStartBpm = spdStartBpm
            item.spdEndBpm = spdEndBpm
            item.spdStepSec = spdStepSec
            item.spdStepBpm = spdStepBpm
            item.spdDirection = spdDirection.rawValue
            item.spdRhythmIndex = spdRhythmIndex
            item.spdVolGuide = spdVolGuide
            item.spdVolPulse = spdVolPulse
        case .oddTime:
            item.oddSignatureKey = oddSignatureKey
            item.oddPatterns = oddPatterns
            item.oddVol = oddVol
        case .modulation:
            item.modMatrixIndex = modMatrixIndex
            item.modVolGuide = modVolGuide
            item.modVolAccent = modVolAccent
            item.modVolNormal = modVolNormal
            item.swingMode = swingMode.rawValue
            item.swingRatio = swingRatio
            item.modTrainingEnabled = modTrainingEnabled
            item.modTrainingCycleBars = modTrainingCycleBars
        }
        setlist.append(item)
        setlistStore.save(setlist)
    }

    func loadSetlistItem(_ item: SetlistItem) {
        stop()
        updateBPM(item.bpm)
        if let ts = item.timeSignature { totalBeatsInBar = ts }
        switch item.mode {
        case "Normal":
            if let sm = item.swingMode { swingMode = SwingMode(rawValue: sm) ?? .off }
            swingRatio = item.swingRatio ?? 0.666
            accentVol = (item.mixerAccent ?? 100) / 100
            quarterVol = (item.mixerQuarter ?? 100) / 100
            eighthVol = (item.mixerEighth ?? 0) / 100
            sixteenthVol = (item.mixerSixteenth ?? 0) / 100
            tripletVol = (item.mixerTriplet ?? 0) / 100
            switchMode(0)
        case "ChangeUp":
            cuSelectedFlags = item.cuSelectedFlags ?? cuSelectedFlags
            cuActiveQueue = item.cuActiveQueue ?? cuActiveQueue
            maxBarsPerPattern = item.maxBarsPerPattern ?? 2
            cuVolGuide = item.cuVolGuide ?? 0.5
            cuVolPulse = item.cuVolPulse ?? 0.9
            cuDirection = DirectionMode(rawValue: item.cuDirection ?? "fwd") ?? .fwd
            switchMode(1)
        case "Speed":
            spdStartBpm = item.spdStartBpm ?? 20
            spdEndBpm = item.spdEndBpm ?? 160
            spdStepSec = item.spdStepSec ?? 0.2
            spdStepBpm = item.spdStepBpm ?? 1
            spdDirection = DirectionMode(rawValue: item.spdDirection ?? "fwd") ?? .fwd
            spdRhythmIndex = item.spdRhythmIndex ?? 4
            spdVolGuide = item.spdVolGuide ?? 0.85
            spdVolPulse = item.spdVolPulse ?? 1.0
            switchMode(2)
        case "OddTime":
            switchMode(3)
            applyOddPreset(item.oddSignatureKey ?? "7/8")
            if let p = item.oddPatterns { oddPatterns = p }
            oddVol = item.oddVol ?? 1.0
        case "Modulation":
            modMatrixIndex = item.modMatrixIndex ?? 0
            modVolGuide = item.modVolGuide ?? 1.0
            modVolAccent = item.modVolAccent ?? 0.85
            modVolNormal = item.modVolNormal ?? 0.5
            if let sm = item.swingMode { swingMode = SwingMode(rawValue: sm) ?? .off }
            swingRatio = item.swingRatio ?? 0.666
            modTrainingEnabled = item.modTrainingEnabled ?? false
            modTrainingCycleBars = item.modTrainingCycleBars ?? 2
            switchMode(4)
        default:
            break
        }
        modal = nil
    }

    func deleteSetlist(at index: Int) {
        guard setlist.indices.contains(index) else { return }
        setlist.remove(at: index)
        setlistStore.save(setlist)
    }

    func handleBackground() {
        engine.setBackgroundScheduling(true)
        if isRunning { BackgroundAudioKeeper.shared.refreshIfNeeded() }
    }

    func handleForeground() {
        engine.setBackgroundScheduling(false)
        AppDelegate.configureAudioSession()
        engine.ensureStarted()
    }
}

extension BeatShiftStore: MetronomeEngineDelegate {
    nonisolated func metronomeDidFlashBeat(_ beat: Int) {
        Task { @MainActor in
            activeBeat = beat
            ringFlash = true
            pendulumSign *= -1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.ringFlash = false
            }
        }
    }

    nonisolated func metronomeDidFlashOddStep(_ step: Int) {
        Task { @MainActor in
            oddFlashStep = step
        }
    }

    nonisolated func metronomeDidUpdateBPM(_ bpm: Int) {
        Task { @MainActor in
            self.bpm = bpm
            self.dialBpmAccum = Double(bpm)
        }
    }

    nonisolated func metronomeDidUpdateHeroLabel(_ text: String) {
        Task { @MainActor in
            heroLabel = text
        }
    }

    nonisolated func metronomeDidUpdateCuUI(note: String, progress: String) {
        Task { @MainActor in
            cuNoteText = note
            cuProgressText = progress
        }
    }

    nonisolated func metronomeDidStop() {
        Task { @MainActor in
            isRunning = false
            BackgroundAudioKeeper.shared.setMetronomeRunning(false)
        }
    }

    nonisolated func metronomeCurrentLangIsJP() -> Bool { snapLangIsJP }
    nonisolated func metronomeNoteLabel(_ key: String) -> String { snapNotes[key] ?? key }
    nonisolated func metronomeBarsUnit() -> String { snapBarsUnit }
    nonisolated func metronomeBarProgress() -> String { snapBarProgress }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
