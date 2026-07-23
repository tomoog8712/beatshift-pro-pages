import AVFoundation
import Foundation

protocol MetronomeEngineDelegate: AnyObject {
    func metronomeDidFlashBeat(_ beat: Int)
    func metronomeDidFlashOddStep(_ step: Int)
    func metronomeDidUpdateBPM(_ bpm: Int)
    func metronomeDidUpdateHeroLabel(_ text: String)
    func metronomeDidUpdateCuUI(note: String, progress: String)
    func metronomeDidStop()
    func metronomeCurrentLangIsJP() -> Bool
    func metronomeNoteLabel(_ key: String) -> String
    func metronomeBarsUnit() -> String
    func metronomeBarProgress() -> String
}

/// Snapshot of mutable playback parameters read each schedule tick.
struct MetronomeConfig {
    var mode: AppMode = .normal
    var bpm: Int = 120
    var soundType: SoundType = .click
    var swingMode: SwingMode = .off
    var swingRatio: Double = 0.666
    var totalBeatsInBar: Int = 4

    var accentVol: Double = 1.0
    var quarterVol: Double = 1.0
    var eighthVol: Double = 0
    var sixteenthVol: Double = 0
    var tripletVol: Double = 0

    var cuVolGuide: Double = 0.50
    var cuVolPulse: Double = 0.90
    var cuActiveQueue: [String] = ["4分音符", "2拍3連", "8分音符", "3連符", "16分音符"]
    var cuDirection: DirectionMode = .fwd
    var maxBarsPerPattern: Int = 2

    var spdStartBpm: Int = 20
    var spdEndBpm: Int = 160
    var spdStepSec: Double = 0.2
    var spdStepBpm: Int = 1
    var spdDirection: DirectionMode = .fwd
    var spdVolGuide: Double = 0.85
    var spdVolPulse: Double = 1.0
    var spdRhythmIndex: Int = 4

    var oddNumerator: Int = 7
    var oddDenominator: Int = 8
    var oddPatterns: [Int] = [1, 0, 0, 1, 0, 0, 0]
    var oddVol: Double = 1.0

    var modMatrixIndex: Int = 2
    var modVolGuide: Double = 1.0
    var modVolAccent: Double = 0.85
    var modVolNormal: Double = 0.50
    var modTrainingEnabled: Bool = false
    var modTrainingCycleBars: Int = 2
}

final class MetronomeEngine {
    weak var delegate: MetronomeEngineDelegate?

    private let engine = AVAudioEngine()
    private let players: [AVAudioPlayerNode] = (0..<8).map { _ in AVAudioPlayerNode() }
    private var playerCursor = 0
    private var samples: SampleLibrary!
    private var playerFormat: AVAudioFormat!
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.beatshift.metronome", qos: .userInteractive)

    private(set) var isRunning = false
    private var config = MetronomeConfig()
    private var scheduleAhead = AppConstants.scheduleAheadForeground

    private var nextEventTime: TimeInterval = 0
    private var currentBeatInBar = 0
    private var currentStepInBeat = 0

    private var currentCuIndex = 0
    private var cuBounceDirection = 1
    private var currentBar = 1
    private var barDuration: Double = 0
    private var cuBarStartTime: Double = 0
    private var cuEventIdx = 0
    private var cuBarEvents: [CuBarEvent] = []
    private var cuCountInBar = 0

    private var spdCountInState = 0
    private var spdAutomatingBpm = 20.0
    private var spdBounceDirection = 1
    private var spdLastBpmUpdateTime: TimeInterval = 0

    private var oddCurrentStep = 0
    private var oddVoiceCounter = 0

    private var modStepIdx = 0
    private var modBeatStartTime: TimeInterval = 0

    private let configLock = NSLock()
    private var _sharedConfig = MetronomeConfig()

    /// Wall-clock anchor so schedule times stay consistent across player nodes.
    private var timelineOriginMedia: TimeInterval = 0
    private var timelineOriginHost: UInt64 = 0

    /// Thread-safe config written from UI, read from audio queue.
    func updateSharedConfig(_ config: MetronomeConfig) {
        configLock.lock()
        _sharedConfig = config
        configLock.unlock()
    }

    private func refreshConfig() {
        configLock.lock()
        config = _sharedConfig
        configLock.unlock()
    }

    init() {
        let main = engine.mainMixerNode
        let hardware = main.outputFormat(forBus: 0)
        let useFormat: AVAudioFormat = {
            if hardware.sampleRate > 0,
               let mono = AVAudioFormat(standardFormatWithSampleRate: hardware.sampleRate, channels: 1) {
                return mono
            }
            return AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        }()
        playerFormat = useFormat
        for p in players {
            engine.attach(p)
            engine.connect(p, to: main, format: useFormat)
        }
        samples = SampleLibrary(format: useFormat)
        do {
            try engine.start()
        } catch {
            NSLog("BeatShiftPro: engine start failed: \(error)")
        }
        for p in players { p.play() }
        resetTimelineAnchor()
    }

    private func resetTimelineAnchor() {
        timelineOriginMedia = CACurrentMediaTime()
        timelineOriginHost = mach_absolute_time()
    }

    func ensureStarted() {
        if !engine.isRunning {
            do { try engine.start() } catch { NSLog("BeatShiftPro: engine restart failed: \(error)") }
        }
        for p in players where !p.isPlaying { p.play() }
    }

    func setBackgroundScheduling(_ background: Bool) {
        scheduleAhead = background
            ? AppConstants.scheduleAheadBackground
            : AppConstants.scheduleAheadForeground
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureStarted()
            self.refreshConfig()
            self.isRunning = true
            self.currentBeatInBar = 0
            self.currentStepInBeat = 0
            self.resetTimelineAnchor()
            self.nextEventTime = self.audioNow() + 0.05

            switch self.config.mode {
            case .changeUp:
                if self.config.cuDirection == .fwd || self.config.cuDirection == .bounce {
                    self.currentCuIndex = 0
                    self.cuBounceDirection = 1
                } else {
                    self.currentCuIndex = max(0, self.config.cuActiveQueue.count - 1)
                }
                self.currentBar = 1
                self.cuCountInBar = 1
                self.prepareNextCuBar()
            case .modulation:
                self.modStepIdx = 0
                self.modBeatStartTime = 0
            case .oddTime:
                self.oddCurrentStep = 0
                self.oddVoiceCounter = 0
            case .speed:
                self.currentBeatInBar = 0
                self.currentStepInBeat = 0
                self.spdCountInState = 1
                self.spdAutomatingBpm = Double(
                    self.config.spdDirection == .rev ? self.config.spdEndBpm : self.config.spdStartBpm
                )
                self.spdBounceDirection = self.config.spdEndBpm >= self.config.spdStartBpm ? 1 : -1
                self.spdLastBpmUpdateTime = self.audioNow()
                self.config.bpm = Int(self.spdAutomatingBpm.rounded())
                DispatchQueue.main.async {
                    self.delegate?.metronomeDidUpdateBPM(self.config.bpm)
                    let jp = self.delegate?.metronomeCurrentLangIsJP() == true
                    self.delegate?.metronomeDidUpdateHeroLabel(jp ? "⏱️ カウントイン" : "Count In")
                }
            case .normal:
                break
            }

            self.startTimer()
            self.scheduler()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.timer?.cancel()
            self.timer = nil
            self.cuCountInBar = 0
            self.spdCountInState = 0
            for p in self.players {
                p.stop()
                p.play()
            }
            self.resetTimelineAnchor()
            DispatchQueue.main.async {
                self.delegate?.metronomeDidUpdateHeroLabel("Tempo")
                self.delegate?.metronomeDidStop()
            }
        }
    }

    private func startTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: AppConstants.lookaheadMs)
        t.setEventHandler { [weak self] in self?.scheduler() }
        t.resume()
        timer = t
    }

    private func audioNow() -> TimeInterval {
        CACurrentMediaTime()
    }

    private func nextPlayer() -> AVAudioPlayerNode {
        let p = players[playerCursor % players.count]
        playerCursor += 1
        return p
    }

    private func scheduler() {
        guard isRunning else { return }
        refreshConfig()
        let current = audioNow()
        if !nextEventTime.isFinite {
            nextEventTime = current + 0.05
        }
        var safety = 0
        while nextEventTime < current + scheduleAhead && safety < 32 {
            scheduleEvent()
            safety += 1
            if !isRunning { break }
        }
    }

    private func scheduleAt(_ time: TimeInterval, key: SampleKey, volume: Double, startOffset: TimeInterval = 0) {
        guard let source = samples.buffer(for: key), volume > 0.001 else { return }
        let when = max(time, audioNow() + 0.002)

        let playBuffer: AVAudioPCMBuffer
        if startOffset > 0 || abs(volume - 1.0) >= 0.01 {
            guard let sliced = slice(source, startOffset: startOffset, volume: Float(min(2.0, max(0, volume)))) else {
                return
            }
            playBuffer = sliced
        } else {
            playBuffer = source
        }

        let node = nextPlayer()
        let delay = when - CACurrentMediaTime()
        if delay <= 0.001 {
            node.scheduleBuffer(playBuffer, at: nil, options: [], completionHandler: nil)
            return
        }
        let hostSeconds = AVAudioTime.seconds(forHostTime: mach_absolute_time()) + delay
        let at = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: hostSeconds))
        node.scheduleBuffer(playBuffer, at: at, options: [], completionHandler: nil)
    }

    private func slice(_ buffer: AVAudioPCMBuffer, startOffset: TimeInterval, volume: Float) -> AVAudioPCMBuffer? {
        let sr = buffer.format.sampleRate
        let startFrame = AVAudioFrameCount(max(0, startOffset * sr))
        guard startFrame < buffer.frameLength else { return nil }
        let frames = buffer.frameLength - startFrame
        guard let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frames) else { return nil }
        out.frameLength = frames
        let channels = Int(buffer.format.channelCount)
        for ch in 0..<channels {
            guard let src = buffer.floatChannelData?[ch], let dst = out.floatChannelData?[ch] else { continue }
            for i in 0..<Int(frames) {
                dst[i] = src[Int(startFrame) + i] * volume
            }
        }
        return out
    }

    private func trigger(_ key: SampleKey, at time: TimeInterval, volume: Double) {
        let offset = samples.onsetOffset(for: key)
        scheduleAt(time, key: key, volume: volume, startOffset: offset)
    }

    private func flashBeat(_ beat: Int, at time: TimeInterval) {
        let delay = max(0, time - audioNow())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.delegate?.metronomeDidFlashBeat(beat)
        }
    }

    private func flashOdd(_ step: Int, at time: TimeInterval) {
        let delay = max(0, time - audioNow())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.delegate?.metronomeDidFlashOddStep(step)
            if step == 0 { self?.delegate?.metronomeDidFlashBeat(0) }
        }
    }

    private func getSwingSubbeatOffset(beatLen: Double, gridPos: Double) -> Double {
        if config.swingMode == .eighth && abs(gridPos - 0.5) < 0.001 {
            return beatLen * config.swingRatio
        }
        if config.swingMode == .sixteenth {
            if abs(gridPos - 0.25) < 0.001 { return beatLen * (config.swingRatio / 2) }
            if abs(gridPos - 0.75) < 0.001 { return beatLen * (0.5 + config.swingRatio / 2) }
        }
        return beatLen * gridPos
    }

    private func playTargetSound(type: SoundType, time: TimeInterval, beatIndex: Int, vol: Double) {
        switch type {
        case .voice:
            triggerVoiceBeatNumber(time: time, beatIndex: beatIndex, vol: vol * 1.5)
        case .woodblock:
            let key: SampleKey = beatIndex == 0 ? .woodAccent : .woodStrong
            trigger(key, at: time, volume: vol)
        case .click:
            let key: SampleKey = beatIndex == 0 ? .clickAccent : .clickStrong
            trigger(key, at: time, volume: vol)
        }
    }

    private func triggerVoiceBeatNumber(time: TimeInterval, beatIndex: Int, vol: Double) {
        let voiceNum = max(1, min(15, (beatIndex % config.totalBeatsInBar) + 1))
        if let key = SampleKey.voice(voiceNum) {
            trigger(key, at: time, volume: vol)
        }
    }

    private func triggerVoiceKey(time: TimeInterval, key: SampleKey, vol: Double) {
        trigger(key, at: time, volume: vol)
    }

    private func triggerVoiceBuffer(time: TimeInterval, beatIndex: Int, vol: Double) {
        triggerVoiceBeatNumber(time: time, beatIndex: beatIndex, vol: vol * 1.5)
    }

    // MARK: - Schedule modes

    private func scheduleEvent() {
        let beatInterval = 60.0 / Double(max(1, config.bpm))

        if isRunning && config.mode == .speed && spdCountInState == 0 {
            let curTime = audioNow()
            if curTime - spdLastBpmUpdateTime >= config.spdStepSec {
                let chunks = Int(floor((curTime - spdLastBpmUpdateTime) / config.spdStepSec))
                var sign = config.spdDirection == .rev ? -1 : 1
                if config.spdDirection == .bounce {
                    sign = spdBounceDirection
                } else if config.spdStartBpm > config.spdEndBpm {
                    sign = -sign
                }

                spdAutomatingBpm += Double(sign * config.spdStepBpm * chunks)
                spdLastBpmUpdateTime += Double(chunks) * config.spdStepSec

                let targetMax = Double(max(config.spdStartBpm, config.spdEndBpm))
                let targetMin = Double(min(config.spdStartBpm, config.spdEndBpm))

                if config.spdDirection == .bounce {
                    if spdAutomatingBpm >= targetMax {
                        spdAutomatingBpm = targetMax
                        spdBounceDirection = -1
                    } else if spdAutomatingBpm <= targetMin {
                        spdAutomatingBpm = targetMin
                        spdBounceDirection = 1
                    }
                } else {
                    if (sign > 0 && spdAutomatingBpm >= targetMax) || (sign < 0 && spdAutomatingBpm <= targetMin) {
                        spdAutomatingBpm = sign > 0 ? targetMax : targetMin
                        let rounded = Int(spdAutomatingBpm.rounded())
                        config.bpm = rounded
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.metronomeDidUpdateBPM(rounded)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                            self?.stop()
                        }
                        return
                    }
                }
                let rounded = Int(spdAutomatingBpm.rounded())
                config.bpm = rounded
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.metronomeDidUpdateBPM(rounded)
                }
                if nextEventTime < audioNow() {
                    nextEventTime = audioNow() + 0.02
                }
            }
        }

        switch config.mode {
        case .normal:
            scheduleNormal(beatInterval: beatInterval)
        case .changeUp:
            scheduleChangeUp(beatInterval: beatInterval)
        case .speed:
            if spdCountInState == 1 {
                scheduleSpdRhythmStep(beatInterval: beatInterval, withClickOnBeat: true, endAfterOneBar: true)
            } else {
                scheduleSpdRhythmStep(beatInterval: beatInterval, withClickOnBeat: false, endAfterOneBar: false)
            }
        case .oddTime:
            scheduleOddTime(beatInterval: beatInterval)
        case .modulation:
            scheduleModulation(beatInterval: beatInterval)
        }
    }

    private func scheduleNormal(beatInterval: Double) {
        let beatLen = beatInterval
        let isFirstBeat = currentBeatInBar == 0
        let isVoice = config.soundType == .voice
        let copyBeat = currentBeatInBar
        flashBeat(copyBeat, at: nextEventTime)

        if isFirstBeat && config.accentVol > 0.01 {
            playTargetSound(type: .woodblock, time: nextEventTime, beatIndex: 0, vol: config.accentVol * 1.2)
        }

        if config.quarterVol > 0.01 {
            if isVoice {
                triggerVoiceBeatNumber(time: nextEventTime, beatIndex: currentBeatInBar, vol: config.quarterVol)
                // Same click underlay on every beat; accent is a separate fader.
                trigger(.woodWeak, at: nextEventTime, volume: config.quarterVol * 0.7)
            } else {
                // Always use non-accent sample (same as beat 2+); accent fader handles beat 1.
                playTargetSound(type: config.soundType, time: nextEventTime, beatIndex: 1, vol: config.quarterVol)
            }
        }

        if config.eighthVol > 0.01 {
            let eighthTime = nextEventTime + getSwingSubbeatOffset(beatLen: beatLen, gridPos: 0.5)
            if isVoice {
                triggerVoiceKey(time: eighthTime, key: .voiceAnd, vol: config.eighthVol)
                trigger(.woodWeak, at: eighthTime, volume: config.eighthVol * 0.5)
            } else {
                trigger(.woodWeak, at: eighthTime, volume: config.eighthVol)
            }
        }

        if config.sixteenthVol > 0.01 {
            let t1 = nextEventTime + getSwingSubbeatOffset(beatLen: beatLen, gridPos: 0.25)
            let t2 = nextEventTime + getSwingSubbeatOffset(beatLen: beatLen, gridPos: 0.75)
            if isVoice {
                triggerVoiceKey(time: t1, key: .voiceE, vol: config.sixteenthVol * 0.9)
                triggerVoiceKey(time: t2, key: .voiceDa, vol: config.sixteenthVol * 0.9)
                trigger(.woodWeak, at: t1, volume: config.sixteenthVol * 0.4)
                trigger(.woodWeak, at: t2, volume: config.sixteenthVol * 0.4)
            } else {
                trigger(.woodWeak, at: t1, volume: config.sixteenthVol * 0.8)
                trigger(.woodWeak, at: t2, volume: config.sixteenthVol * 0.8)
            }
        }

        if config.tripletVol > 0.01 {
            let t1 = nextEventTime + beatLen * (1.0 / 3.0)
            let t2 = nextEventTime + beatLen * (2.0 / 3.0)
            if isVoice {
                triggerVoiceKey(time: t1, key: .voiceE, vol: config.tripletVol * 0.9)
                triggerVoiceKey(time: t2, key: .voiceDa, vol: config.tripletVol * 0.9)
                trigger(.woodWeak, at: t1, volume: config.tripletVol * 0.4)
                trigger(.woodWeak, at: t2, volume: config.tripletVol * 0.4)
            } else {
                trigger(.woodWeak, at: t1, volume: config.tripletVol * 0.8)
                trigger(.woodWeak, at: t2, volume: config.tripletVol * 0.8)
            }
        }

        nextEventTime += beatLen
        currentBeatInBar = (currentBeatInBar + 1) % config.totalBeatsInBar
    }

    private func generateCuTimeline(type: String, duration: Double) -> [(t: Double, s: String)] {
        var events: [(Double, String)] = []
        let beats = Double(config.totalBeatsInBar)
        switch type {
        case "全音符":
            events.append((0, "accent"))
        case "2分音符":
            events += [(0, "accent"), (duration / 2, "sub")]
        case "4分音符":
            for i in 0..<config.totalBeatsInBar {
                events.append((duration * Double(i) / beats, i == 0 ? "accent" : "sub"))
            }
        case "8分音符":
            for i in 0..<(config.totalBeatsInBar * 2) {
                events.append((duration * Double(i) / (beats * 2), i == 0 ? "accent" : "sub"))
            }
        case "3連符":
            for i in 0..<(config.totalBeatsInBar * 3) {
                events.append((duration * Double(i) / (beats * 3), i == 0 ? "accent" : "sub"))
            }
        case "16分音符":
            for i in 0..<(config.totalBeatsInBar * 4) {
                events.append((duration * Double(i) / (beats * 4), i == 0 ? "accent" : "sub"))
            }
        case "6連符":
            for i in 0..<(config.totalBeatsInBar * 6) {
                events.append((duration * Double(i) / (beats * 6), i == 0 ? "accent" : "sub"))
            }
        case "32分音符":
            for i in 0..<(config.totalBeatsInBar * 8) {
                events.append((duration * Double(i) / (beats * 8), i == 0 ? "accent" : "sub"))
            }
        case "4拍3連":
            events += [(0, "accent"), (duration / 3, "sub"), (duration * 2 / 3, "sub")]
        case "4拍5連":
            for i in 0..<5 { events.append((duration * Double(i) / 5, i == 0 ? "accent" : "sub")) }
        case "4拍7連":
            for i in 0..<7 { events.append((duration * Double(i) / 7, i == 0 ? "accent" : "sub")) }
        case "4拍9連":
            for i in 0..<9 { events.append((duration * Double(i) / 9, i == 0 ? "accent" : "sub")) }
        case "2拍3連":
            for i in 0..<6 { events.append((duration * Double(i) / 6, i == 0 ? "accent" : "sub")) }
        case "2拍5連":
            for i in 0..<10 { events.append((duration * Double(i) / 10, i == 0 ? "accent" : "sub")) }
        case "2拍7連符", "2拍7連":
            for i in 0..<14 { events.append((duration * Double(i) / 14, i == 0 ? "accent" : "sub")) }
        default:
            break
        }
        return events
    }

    private func prepareNextCuBar() {
        barDuration = (60.0 / Double(max(1, config.bpm))) * Double(config.totalBeatsInBar)
        cuBarStartTime = nextEventTime
        cuEventIdx = 0
        cuBarEvents = []

        if cuCountInBar == 1 {
            cuBarEvents.append(CuBarEvent(t: 0, type: "countin", sound: "voice_1", text: "1..."))
            if config.totalBeatsInBar >= 3 {
                cuBarEvents.append(CuBarEvent(
                    t: barDuration * 2 / Double(config.totalBeatsInBar),
                    type: "countin", sound: "voice_2", text: "2..."
                ))
            }
            return
        }
        if cuCountInBar == 2 {
            for i in 0..<config.totalBeatsInBar {
                let txt = (0...i).map { String($0 + 1) }.joined(separator: ".")
                cuBarEvents.append(CuBarEvent(
                    t: barDuration * Double(i) / Double(config.totalBeatsInBar),
                    type: "countin", sound: "voice_\(i + 1)", text: txt
                ))
            }
            return
        }

        if currentCuIndex < 0 { currentCuIndex = 0 }
        if currentCuIndex >= config.cuActiveQueue.count {
            currentCuIndex = max(0, config.cuActiveQueue.count - 1)
        }
        let activeType = config.cuActiveQueue.isEmpty
            ? "4分音符"
            : (config.cuActiveQueue[safe: currentCuIndex] ?? "4分音符")
        let clickEvents = generateCuTimeline(type: activeType, duration: barDuration)
        for ev in clickEvents {
            cuBarEvents.append(CuBarEvent(t: ev.t, type: "click", sound: ev.s, text: nil))
        }
        for i in 0..<config.totalBeatsInBar {
            cuBarEvents.append(CuBarEvent(
                t: barDuration * Double(i) / Double(config.totalBeatsInBar),
                type: "base_quarter",
                sound: i == 0 ? "base_accent" : "base_strong",
                text: nil
            ))
        }
        cuBarEvents.sort { $0.t < $1.t }
    }

    private func scheduleChangeUp(beatInterval: Double) {
        if cuEventIdx < cuBarEvents.count {
            let ev = cuBarEvents[cuEventIdx]
            let evAbsTime = cuBarStartTime + ev.t

            if ev.type == "countin" {
                let beatNumber = Int((ev.t / beatInterval).rounded())
                let delay = max(0, evAbsTime - audioNow())
                let text = ev.text ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self else { return }
                    self.delegate?.metronomeDidFlashBeat(beatNumber)
                    if self.cuCountInBar > 0 {
                        let jp = self.delegate?.metronomeCurrentLangIsJP() == true
                        self.delegate?.metronomeDidUpdateCuUI(
                            note: text,
                            progress: jp ? "⏱️ カウントイン" : "Count In"
                        )
                    }
                }
                if let key = SampleKey(rawValue: ev.sound) {
                    trigger(key, at: evAbsTime, volume: 1.5)
                } else {
                    trigger(beatNumber == 0 ? .clickAccent : .clickStrong, at: evAbsTime, volume: 1.0)
                }
            } else if ev.type == "base_quarter" {
                let beatNumber = Int((ev.t / beatInterval).rounded())
                let delay = max(0, evAbsTime - audioNow())
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.delegate?.metronomeDidFlashBeat(beatNumber)
                    self?.pushCuUI()
                }
                triggerVoiceBuffer(time: evAbsTime, beatIndex: beatNumber, vol: config.cuVolGuide)
                trigger(beatNumber == 0 ? .clickAccent : .clickStrong, at: evAbsTime, volume: config.cuVolGuide * 0.7)
            } else if ev.type == "click" {
                trigger(.woodWeak, at: evAbsTime, volume: config.cuVolPulse)
            }
            nextEventTime = evAbsTime + 0.001
            cuEventIdx += 1
        } else {
            nextEventTime = cuBarStartTime + barDuration
            currentStepInBeat = 0

            if cuCountInBar == 1 {
                cuCountInBar = 2
                prepareNextCuBar()
            } else if cuCountInBar == 2 {
                cuCountInBar = 0
                pushCuUI()
                prepareNextCuBar()
            } else {
                if currentBar < config.maxBarsPerPattern {
                    currentBar += 1
                } else {
                    currentBar = 1
                    let queueCount = max(1, config.cuActiveQueue.count)
                    switch config.cuDirection {
                    case .fwd:
                        currentCuIndex = (currentCuIndex + 1) % queueCount
                    case .rev:
                        currentCuIndex -= 1
                        if currentCuIndex < 0 { currentCuIndex = queueCount - 1 }
                    case .bounce:
                        currentCuIndex += cuBounceDirection
                        if currentCuIndex >= queueCount {
                            cuBounceDirection = -1
                            currentCuIndex = max(0, queueCount - 2)
                        } else if currentCuIndex < 0 {
                            cuBounceDirection = 1
                            currentCuIndex = min(1, queueCount - 1)
                        }
                    }
                }
                prepareNextCuBar()
                DispatchQueue.main.async { [weak self] in self?.pushCuUI() }
            }
        }
    }

    private func pushCuUI() {
        guard cuCountInBar == 0 else { return }
        let activeType = config.cuActiveQueue[safe: currentCuIndex] ?? "4分音符"
        let note = delegate?.metronomeNoteLabel(activeType) ?? activeType
        let progressUnit = delegate?.metronomeBarProgress() ?? "Bars"
        let barsUnit = delegate?.metronomeBarsUnit() ?? "Bars"
        delegate?.metronomeDidUpdateCuUI(
            note: note,
            progress: "\(currentBar) \(progressUnit) / \(config.maxBarsPerPattern) \(barsUnit)"
        )
    }

    private func scheduleSpdRhythmStep(beatInterval: Double, withClickOnBeat: Bool, endAfterOneBar: Bool) {
        let rhythmType = RhythmType.spdRhythmPool[safe: config.spdRhythmIndex] ?? "16分音符"
        var divisions = 4
        if rhythmType == "4分音符" { divisions = 1 }
        else if rhythmType == "8分音符" { divisions = 2 }
        else if rhythmType == "3連符" { divisions = 3 }
        else if rhythmType == "16分音符" { divisions = 4 }
        let is2beat3 = rhythmType == "2拍3連"
        let stepInterval = is2beat3 ? (beatInterval * 2 / 3) : (beatInterval / Double(divisions))

        if is2beat3 {
            let virtualOddStep = currentStepInBeat % 3
            let copyBeat = (currentStepInBeat / 3) * 2
            if virtualOddStep == 0 {
                flashBeat(copyBeat, at: nextEventTime)
                triggerVoiceBuffer(time: nextEventTime, beatIndex: copyBeat, vol: config.spdVolGuide)
                if withClickOnBeat {
                    trigger(copyBeat == 0 ? .clickAccent : .clickStrong, at: nextEventTime, volume: config.spdVolGuide * 0.7)
                }
            }
            trigger(.woodWeak, at: nextEventTime, volume: config.spdVolPulse)
            nextEventTime += stepInterval
            currentStepInBeat += 1
            if endAfterOneBar {
                if currentStepInBeat >= 6 {
                    currentStepInBeat = 0
                    currentBeatInBar = 0
                    spdCountInState = 0
                    spdLastBpmUpdateTime = nextEventTime
                    let delay = max(0, nextEventTime - audioNow())
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.delegate?.metronomeDidUpdateHeroLabel("Tempo")
                    }
                }
            } else if currentStepInBeat >= 6 {
                currentStepInBeat = 0
            }
            return
        }

        if currentStepInBeat == 0 {
            let copyBeat = currentBeatInBar
            flashBeat(copyBeat, at: nextEventTime)
            triggerVoiceBuffer(time: nextEventTime, beatIndex: copyBeat, vol: config.spdVolGuide)
            if withClickOnBeat {
                trigger(currentBeatInBar == 0 ? .clickAccent : .clickStrong, at: nextEventTime, volume: config.spdVolGuide * 0.7)
            }
        }
        trigger(.woodWeak, at: nextEventTime, volume: config.spdVolPulse)
        nextEventTime += stepInterval
        currentStepInBeat += 1
        if currentStepInBeat >= divisions {
            currentStepInBeat = 0
            currentBeatInBar += 1
            if endAfterOneBar && currentBeatInBar >= 4 {
                currentBeatInBar = 0
                spdCountInState = 0
                spdLastBpmUpdateTime = nextEventTime
                let delay = max(0, nextEventTime - audioNow())
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.delegate?.metronomeDidUpdateHeroLabel("Tempo")
                }
            } else if !endAfterOneBar {
                currentBeatInBar = currentBeatInBar % 4
            }
        }
    }

    private func scheduleOddTime(beatInterval: Double) {
        let stepFactor = 4.0 / Double(config.oddDenominator)
        let stepInterval = beatInterval * stepFactor
        let copyStep = oddCurrentStep
        flashOdd(copyStep, at: nextEventTime)

        let isAccent = (config.oddPatterns[safe: oddCurrentStep] ?? 0) != 0
        if oddCurrentStep == 0 || isAccent {
            oddVoiceCounter = 0
        }

        if config.soundType == .voice {
            if oddVoiceCounter < config.oddNumerator {
                if let key = SampleKey.voice(oddVoiceCounter + 1) {
                    trigger(key, at: nextEventTime, volume: config.oddVol * 1.5)
                }
            }
            trigger(isAccent ? .clickAccent : .clickStrong, at: nextEventTime, volume: isAccent ? config.oddVol * 1.2 : config.oddVol * 0.6)
        } else {
            if oddCurrentStep == 0 {
                trigger(.woodAccent, at: nextEventTime, volume: config.oddVol * 1.3)
            } else if isAccent {
                playTargetSound(type: config.soundType, time: nextEventTime, beatIndex: oddCurrentStep, vol: config.oddVol * 1.2)
            } else {
                trigger(.woodWeak, at: nextEventTime, volume: config.oddVol * 0.8)
            }
        }

        nextEventTime += stepInterval
        oddCurrentStep = (oddCurrentStep + 1) % config.oddNumerator
        oddVoiceCounter += 1
    }

    private func scheduleModulation(beatInterval: Double) {
        let activeModType = RhythmType.modMatrixPool[safe: config.modMatrixIndex] ?? "16分7つ割り"
        var stepsPerBeat = 4
        var groupCount = 3
        if let range = activeModType.range(of: #"(\d+)つ割り"#, options: .regularExpression) {
            let digits = activeModType[range].filter(\.isNumber)
            if let g = Int(digits) { groupCount = g }
        }
        if activeModType.contains("16分") { stepsPerBeat = 4 }
        else if activeModType.contains("8分") { stepsPerBeat = 2 }
        else if activeModType.contains("3連") { stepsPerBeat = 3 }

        let s = modStepIdx % stepsPerBeat
        let isBeatHead = s == 0
        let isBarHead = modStepIdx % (stepsPerBeat * config.totalBeatsInBar) == 0
        let beatLen = beatInterval
        if isBeatHead { modBeatStartTime = nextEventTime }
        let eventTime = modBeatStartTime + getSwingSubbeatOffset(beatLen: beatLen, gridPos: Double(s) / Double(stepsPerBeat))

        let stepsPerBar = stepsPerBeat * config.totalBeatsInBar
        let currentBarCount = modStepIdx / stepsPerBar
        var isMutedPeriod = false
        if config.modTrainingEnabled {
            let cycleBlock = currentBarCount / config.modTrainingCycleBars
            if cycleBlock % 2 == 1 { isMutedPeriod = true }
        }

        if isBeatHead {
            let beatInBar = (modStepIdx % (stepsPerBeat * config.totalBeatsInBar)) / stepsPerBeat
            if !isMutedPeriod {
                let voiceNum = (beatInBar % 8) + 1
                if let key = SampleKey.voice(voiceNum) {
                    trigger(key, at: eventTime, volume: config.modVolGuide * 1.5)
                }
                trigger(isBarHead ? .clickAccent : .clickStrong, at: eventTime, volume: config.modVolGuide * 0.8)
            }
            flashBeat(beatInBar, at: eventTime)
        }

        let isAccent = modStepIdx % groupCount == 0
        let woodKey: SampleKey = isAccent ? .woodAccent : .woodStrong
        let currentVol = isAccent ? config.modVolAccent : config.modVolNormal
        let currentKey: SampleKey = isAccent ? woodKey : .woodModNormal
        trigger(currentKey, at: eventTime, volume: currentVol)

        let nextS = (s + 1) % stepsPerBeat
        if nextS == 0 {
            nextEventTime = modBeatStartTime + beatLen
        } else {
            nextEventTime = modBeatStartTime + getSwingSubbeatOffset(beatLen: beatLen, gridPos: Double(nextS) / Double(stepsPerBeat))
        }
        modStepIdx += 1
        if modStepIdx >= 999_999 {
            let alignUnit = stepsPerBar * groupCount
            modStepIdx = modStepIdx % alignUnit
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
