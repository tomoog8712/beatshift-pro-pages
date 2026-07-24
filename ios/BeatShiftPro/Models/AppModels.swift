import Foundation

enum AppMode: String, CaseIterable, Codable {
    case normal = "Normal"
    case changeUp = "ChangeUp"
    case speed = "Speed"
    case oddTime = "OddTime"
    case modulation = "Modulation"

    var tabIndex: Int {
        switch self {
        case .normal: return 0
        case .changeUp: return 1
        case .speed: return 2
        case .oddTime: return 3
        case .modulation: return 4
        }
    }

    static func from(index: Int) -> AppMode {
        switch index {
        case 1: return .changeUp
        case 2: return .speed
        case 3: return .oddTime
        case 4: return .modulation
        default: return .normal
        }
    }
}

enum SoundType: String, CaseIterable, Codable {
    case click = "Click"
    case woodblock = "Woodblock"
    case voice = "Voice"
}

enum SwingMode: String, Codable {
    case off
    case eighth
    case sixteenth
}

enum DirectionMode: String, Codable, Hashable {
    case fwd
    case rev
    case bounce
}

enum SampleKey: String, CaseIterable {
    case voice1 = "voice_1"
    case voice2 = "voice_2"
    case voice3 = "voice_3"
    case voice4 = "voice_4"
    case voice5 = "voice_5"
    case voice6 = "voice_6"
    case voice7 = "voice_7"
    case voice8 = "voice_8"
    case voice9 = "voice_9"
    case voice10 = "voice_10"
    case voice11 = "voice_11"
    case voice12 = "voice_12"
    case voice13 = "voice_13"
    case voice14 = "voice_14"
    case voice15 = "voice_15"
    case voiceAnd = "voice_and"
    case voiceE = "voice_e"
    case voiceDa = "voice_da"
    case clickAccent = "global_click_accent"
    case clickStrong = "global_click_strong"
    case woodAccent = "wood_accent"
    case woodStrong = "wood_strong"
    case woodWeak = "wood_weak"
    case woodModNormal = "wood_mod_normal"

    var fileName: String {
        switch self {
        case .voice1: return "one"
        case .voice2: return "two"
        case .voice3: return "three"
        case .voice4: return "four"
        case .voice5: return "five"
        case .voice6: return "six"
        case .voice7: return "seven"
        case .voice8: return "eight"
        case .voice9: return "nine"
        case .voice10: return "ten"
        case .voice11: return "eleven"
        case .voice12: return "twelve"
        case .voice13: return "thirteen"
        case .voice14: return "fourteen"
        case .voice15: return "fifteen"
        case .voiceAnd: return "and"
        case .voiceE: return "e"
        case .voiceDa: return "da"
        case .clickAccent: return "click_accent"
        case .clickStrong: return "click_strong"
        case .woodAccent: return "wood_accent"
        case .woodStrong: return "wood_strong"
        case .woodWeak: return "wood_weak"
        case .woodModNormal: return "wood_mod_normal"
        }
    }

    static func voice(_ n: Int) -> SampleKey? {
        SampleKey(rawValue: "voice_\(n)")
    }
}

enum RhythmType {
    static let cuSequence = [
        "全音符", "2分音符", "4拍3連", "4分音符", "4拍5連", "2拍3連", "4拍7連",
        "8分音符", "4拍9連", "2拍5連", "3連符", "2拍7連符", "16分音符", "6連符", "32分音符"
    ]

    static let modMatrixPool = [
        "16分3つ割り", "16分5つ割り", "16分7つ割り",
        "8分3つ割り", "8分5つ割り", "8分7つ割り",
        "3連4つ割り", "3連5つ割り", "3連7つ割り"
    ]

    static let spdRhythmPool = ["2拍3連", "4分音符", "8分音符", "3連符", "16分音符"]

    static let oddPresets: [String: (num: Int, den: Int, pat: [Int])] = [
        "5/4": (5, 4, [1, 0, 0, 0, 0]),
        "7/8": (7, 8, [1, 0, 0, 0, 0, 0, 0]),
        "9/8": (9, 8, [1, 0, 0, 0, 0, 0, 0, 0, 0])
    ]
}

enum AppConstants {
    static let bpmMin = 30
    /// シーケンス（Normal）モードの BPM 範囲
    static let seqBpmMin = 1
    static let seqBpmMax = 500
    static let spdBpmMin = 20
    static let bpmMax = 300
    static let bpmPerDegree = 0.25
    static let voiceStartOffset: TimeInterval = 0.12
    static let lookaheadMs: TimeInterval = 0.015
    static let scheduleAheadForeground: TimeInterval = 0.15
    static let scheduleAheadBackground: TimeInterval = 2.0
    static let setlistKey = "metronome_global_setlist_v6_speed_automation"
}

struct ModeSettings {
    var bpm: Int
    var soundType: SoundType
}

struct CuBarEvent {
    var t: Double
    var type: String
    var sound: String
    var text: String?
}

struct SetlistItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var bpm: Int
    var mode: String
    var timeSignature: Int?

    var swingMode: String?
    var swingRatio: Double?
    var mixerAccent: Double?
    var mixerQuarter: Double?
    var mixerEighth: Double?
    var mixerSixteenth: Double?
    var mixerTriplet: Double?

    var cuSelectedFlags: [Bool]?
    var cuActiveQueue: [String]?
    var maxBarsPerPattern: Int?
    var cuVolGuide: Double?
    var cuVolPulse: Double?
    var cuDirection: String?

    var spdStartBpm: Int?
    var spdEndBpm: Int?
    var spdStepSec: Double?
    var spdStepBpm: Int?
    var spdDirection: String?
    var spdRhythmIndex: Int?
    var spdVolGuide: Double?
    var spdVolPulse: Double?

    var oddSignatureKey: String?
    var oddPatterns: [Int]?
    var oddVol: Double?

    var modMatrixIndex: Int?
    var modVolGuide: Double?
    var modVolAccent: Double?
    var modVolNormal: Double?
    var modTrainingEnabled: Bool?
    var modTrainingCycleBars: Int?

    enum CodingKeys: String, CodingKey {
        case name, bpm, mode, timeSignature
        case swingMode, swingRatio, mixerAccent, mixerQuarter, mixerEighth, mixerSixteenth, mixerTriplet
        case cuSelectedFlags, cuActiveQueue, maxBarsPerPattern, cuVolGuide, cuVolPulse, cuDirection
        case spdStartBpm, spdEndBpm, spdStepSec, spdStepBpm, spdDirection, spdRhythmIndex, spdVolGuide, spdVolPulse
        case oddSignatureKey, oddPatterns, oddVol
        case modMatrixIndex, modVolGuide, modVolAccent, modVolNormal, modTrainingEnabled, modTrainingCycleBars
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try c.decode(String.self, forKey: .name)
        bpm = try c.decode(Int.self, forKey: .bpm)
        mode = try c.decode(String.self, forKey: .mode)
        timeSignature = try c.decodeIfPresent(Int.self, forKey: .timeSignature)
        swingMode = try c.decodeIfPresent(String.self, forKey: .swingMode)
        swingRatio = try c.decodeIfPresent(Double.self, forKey: .swingRatio)
        mixerAccent = try c.decodeIfPresent(Double.self, forKey: .mixerAccent)
        mixerQuarter = try c.decodeIfPresent(Double.self, forKey: .mixerQuarter)
        mixerEighth = try c.decodeIfPresent(Double.self, forKey: .mixerEighth)
        mixerSixteenth = try c.decodeIfPresent(Double.self, forKey: .mixerSixteenth)
        mixerTriplet = try c.decodeIfPresent(Double.self, forKey: .mixerTriplet)
        cuSelectedFlags = try c.decodeIfPresent([Bool].self, forKey: .cuSelectedFlags)
        cuActiveQueue = try c.decodeIfPresent([String].self, forKey: .cuActiveQueue)
        maxBarsPerPattern = try c.decodeIfPresent(Int.self, forKey: .maxBarsPerPattern)
        cuVolGuide = try c.decodeIfPresent(Double.self, forKey: .cuVolGuide)
        cuVolPulse = try c.decodeIfPresent(Double.self, forKey: .cuVolPulse)
        cuDirection = try c.decodeIfPresent(String.self, forKey: .cuDirection)
        spdStartBpm = try c.decodeIfPresent(Int.self, forKey: .spdStartBpm)
        spdEndBpm = try c.decodeIfPresent(Int.self, forKey: .spdEndBpm)
        spdStepSec = try c.decodeIfPresent(Double.self, forKey: .spdStepSec)
        spdStepBpm = try c.decodeIfPresent(Int.self, forKey: .spdStepBpm)
        spdDirection = try c.decodeIfPresent(String.self, forKey: .spdDirection)
        spdRhythmIndex = try c.decodeIfPresent(Int.self, forKey: .spdRhythmIndex)
        spdVolGuide = try c.decodeIfPresent(Double.self, forKey: .spdVolGuide)
        spdVolPulse = try c.decodeIfPresent(Double.self, forKey: .spdVolPulse)
        oddSignatureKey = try c.decodeIfPresent(String.self, forKey: .oddSignatureKey)
        oddPatterns = try c.decodeIfPresent([Int].self, forKey: .oddPatterns)
        oddVol = try c.decodeIfPresent(Double.self, forKey: .oddVol)
        modMatrixIndex = try c.decodeIfPresent(Int.self, forKey: .modMatrixIndex)
        modVolGuide = try c.decodeIfPresent(Double.self, forKey: .modVolGuide)
        modVolAccent = try c.decodeIfPresent(Double.self, forKey: .modVolAccent)
        modVolNormal = try c.decodeIfPresent(Double.self, forKey: .modVolNormal)
        modTrainingEnabled = try c.decodeIfPresent(Bool.self, forKey: .modTrainingEnabled)
        modTrainingCycleBars = try c.decodeIfPresent(Int.self, forKey: .modTrainingCycleBars)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(bpm, forKey: .bpm)
        try c.encode(mode, forKey: .mode)
        try c.encodeIfPresent(timeSignature, forKey: .timeSignature)
        try c.encodeIfPresent(swingMode, forKey: .swingMode)
        try c.encodeIfPresent(swingRatio, forKey: .swingRatio)
        try c.encodeIfPresent(mixerAccent, forKey: .mixerAccent)
        try c.encodeIfPresent(mixerQuarter, forKey: .mixerQuarter)
        try c.encodeIfPresent(mixerEighth, forKey: .mixerEighth)
        try c.encodeIfPresent(mixerSixteenth, forKey: .mixerSixteenth)
        try c.encodeIfPresent(mixerTriplet, forKey: .mixerTriplet)
        try c.encodeIfPresent(cuSelectedFlags, forKey: .cuSelectedFlags)
        try c.encodeIfPresent(cuActiveQueue, forKey: .cuActiveQueue)
        try c.encodeIfPresent(maxBarsPerPattern, forKey: .maxBarsPerPattern)
        try c.encodeIfPresent(cuVolGuide, forKey: .cuVolGuide)
        try c.encodeIfPresent(cuVolPulse, forKey: .cuVolPulse)
        try c.encodeIfPresent(cuDirection, forKey: .cuDirection)
        try c.encodeIfPresent(spdStartBpm, forKey: .spdStartBpm)
        try c.encodeIfPresent(spdEndBpm, forKey: .spdEndBpm)
        try c.encodeIfPresent(spdStepSec, forKey: .spdStepSec)
        try c.encodeIfPresent(spdStepBpm, forKey: .spdStepBpm)
        try c.encodeIfPresent(spdDirection, forKey: .spdDirection)
        try c.encodeIfPresent(spdRhythmIndex, forKey: .spdRhythmIndex)
        try c.encodeIfPresent(spdVolGuide, forKey: .spdVolGuide)
        try c.encodeIfPresent(spdVolPulse, forKey: .spdVolPulse)
        try c.encodeIfPresent(oddSignatureKey, forKey: .oddSignatureKey)
        try c.encodeIfPresent(oddPatterns, forKey: .oddPatterns)
        try c.encodeIfPresent(oddVol, forKey: .oddVol)
        try c.encodeIfPresent(modMatrixIndex, forKey: .modMatrixIndex)
        try c.encodeIfPresent(modVolGuide, forKey: .modVolGuide)
        try c.encodeIfPresent(modVolAccent, forKey: .modVolAccent)
        try c.encodeIfPresent(modVolNormal, forKey: .modVolNormal)
        try c.encodeIfPresent(modTrainingEnabled, forKey: .modTrainingEnabled)
        try c.encodeIfPresent(modTrainingCycleBars, forKey: .modTrainingCycleBars)
    }

    init(
        name: String, bpm: Int, mode: String, timeSignature: Int? = nil
    ) {
        self.name = name
        self.bpm = bpm
        self.mode = mode
        self.timeSignature = timeSignature
    }
}
