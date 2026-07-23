import AVFoundation
import Foundation

final class SampleLibrary {
    private(set) var buffers: [SampleKey: AVAudioPCMBuffer] = [:]
    /// Seconds to skip so the audible attack lands on the beat (voices only).
    private(set) var onsetOffsets: [SampleKey: TimeInterval] = [:]
    private let format: AVAudioFormat

    init(format: AVAudioFormat) {
        self.format = format
        loadAll()
    }

    func buffer(for key: SampleKey) -> AVAudioPCMBuffer? {
        buffers[key]
    }

    func onsetOffset(for key: SampleKey) -> TimeInterval {
        onsetOffsets[key] ?? 0
    }

    private func loadAll() {
        for key in SampleKey.allCases {
            if let buf = loadWAV(named: key.fileName) {
                buffers[key] = buf
                if key.isVoice {
                    onsetOffsets[key] = computeOnsetOffset(buf)
                }
            } else if let synth = synthesize(for: key) {
                buffers[key] = synth
            }
        }
    }

    /// Skip soft attack so energy hits nearer the beat (clicks have ~0ms peak; voices peak later).
    private func computeOnsetOffset(_ buffer: AVAudioPCMBuffer) -> TimeInterval {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var peak: Float = 0
        for i in 0..<count {
            peak = max(peak, abs(data[i]))
        }
        guard peak > 0.02 else { return 0 }
        let threshold = peak * 0.40
        let sr = buffer.format.sampleRate
        for i in 0..<count {
            if abs(data[i]) >= threshold {
                // Cap so we never eat the whole sample; match HTML's 120ms max for soft voices.
                return min(0.12, Double(i) / sr)
            }
        }
        return 0
    }

    private func loadWAV(named name: String) -> AVAudioPCMBuffer? {
        let url =
            Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: name, withExtension: "wav")
        guard let url else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            let capacity = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
                return nil
            }
            try file.read(into: buffer)
            return convert(buffer, to: format) ?? buffer
        } catch {
            NSLog("BeatShiftPro: failed to load \(name).wav: \(error)")
            return nil
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format.sampleRate == format.sampleRate && buffer.format.channelCount == format.channelCount {
            return buffer
        }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var error: NSError?
        var consumed = false
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }

    private func synthesize(for key: SampleKey) -> AVAudioPCMBuffer? {
        switch key {
        case .woodAccent:
            return synthWood(freq: 1760, duration: 0.12, volume: 1.0)
        case .woodStrong, .clickAccent, .clickStrong:
            return synthWood(freq: 1380, duration: 0.12, volume: 1.0)
        case .woodWeak, .woodModNormal:
            return synthWood(freq: 1100, duration: 0.08, volume: 0.8)
        default:
            return synthClick(duration: 0.05)
        }
    }

    private func synthWood(freq: Double, duration: Double, volume: Double) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let frames = AVAudioFrameCount(sr * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let data = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            let envBody = exp(-55 * t)
            let envClick = exp(-350 * t)
            let body = 0.5 * sin(2 * .pi * freq * t)
                + 0.3 * sin(2 * .pi * freq * 1.5 * t)
                + 0.15 * sin(2 * .pi * freq * 2.1 * t)
            let click = 0.35 * (Double.random(in: -1...1)) * envClick
            data[i] = Float(volume * (body * envBody + click))
        }
        return buffer
    }

    private func synthClick(duration: Double) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let frames = AVAudioFrameCount(sr * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let data = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            let env = exp(-200 * t)
            data[i] = Float(0.8 * sin(2 * .pi * 2000 * t) * env)
        }
        return buffer
    }
}

extension SampleKey {
    var isVoice: Bool {
        switch self {
        case .voice1, .voice2, .voice3, .voice4, .voice5, .voice6, .voice7, .voice8, .voice9,
             .voice10, .voice11, .voice12, .voice13, .voice14, .voice15,
             .voiceAnd, .voiceE, .voiceDa:
            return true
        default:
            return false
        }
    }
}
