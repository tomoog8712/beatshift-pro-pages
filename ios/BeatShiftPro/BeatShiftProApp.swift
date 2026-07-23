import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit

/*
 Google Mobile Ads SPM 追加後、以下の import と start() が有効になります。
 File → Add Package Dependencies…
 → https://github.com/googleads/swift-package-manager-google-mobile-ads
 */
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

extension Notification.Name {
    static let beatshiftWillBackground = Notification.Name("beatshiftWillBackground")
    static let beatshiftDidForeground = Notification.Name("beatshiftDidForeground")
}

@main
struct BeatShiftProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.configureAudioSession()
        Self.startAdMobIfAvailable()
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            Self.handleInterruption(notification)
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Self.configureAudioSession()
            BackgroundAudioKeeper.shared.refreshIfNeeded()
            NotificationCenter.default.post(name: .beatshiftWillBackground, object: nil)
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Self.configureAudioSession()
            NotificationCenter.default.post(name: .beatshiftDidForeground, object: nil)
        }
        return true
    }

    private static func startAdMobIfAvailable() {
        #if canImport(GoogleMobileAds)
        // SDK 初期化完了後にバナー読み込みが安定する
        MobileAds.shared.start { status in
            NSLog("BeatShiftPro AdMob: SDK started — \(status.adapterStatusesByClassName.count) adapters")
        }
        #endif
    }

    static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            NSLog("BeatShiftPro: AVAudioSession setup failed: \(error)")
        }
    }

    private static func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }
        if type == .ended {
            configureAudioSession()
            BackgroundAudioKeeper.shared.refreshIfNeeded()
        }
    }
}

/// Keeps Now Playing / background audio entitlement alive while the metronome runs.
final class BackgroundAudioKeeper {
    static let shared = BackgroundAudioKeeper()

    private(set) var isMetronomeRunning = false
    private var player: AVAudioPlayer?

    private init() {}

    func setMetronomeRunning(_ running: Bool) {
        isMetronomeRunning = running
        if running {
            start()
        } else {
            stop()
        }
    }

    func refreshIfNeeded() {
        if isMetronomeRunning {
            start()
        }
    }

    private func start() {
        AppDelegate.configureAudioSession()
        ensurePlayer()
        guard let player else { return }
        if !player.isPlaying {
            player.play()
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "BeatShift Pro",
            MPMediaItemPropertyArtist: "Metronome",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyIsLiveStream: true
        ]
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func stop() {
        player?.stop()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func ensurePlayer() {
        if player != nil { return }
        do {
            let url = try writeQuietLoopWav()
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.001
            p.prepareToPlay()
            player = p
        } catch {
            NSLog("BeatShiftPro: background keeper failed: \(error)")
        }
    }

    private func writeQuietLoopWav() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("beatshift-keeper.wav")
        let sampleRate = 44100
        let samples = sampleRate
        var data = Data()
        func appendUInt32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        let dataSize = UInt32(samples * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(dataSize)
        var pcm = Data()
        pcm.reserveCapacity(samples * 2)
        for i in 0..<samples {
            let t = Double(i) / Double(sampleRate)
            let sample = Int16((sin(2.0 * Double.pi * 20.0 * t) * 30.0).rounded())
            var le = sample.littleEndian
            withUnsafeBytes(of: &le) { pcm.append(contentsOf: $0) }
        }
        data.append(pcm)
        try data.write(to: url, options: .atomic)
        return url
    }

    func configureRemoteCommands(play: @escaping () -> Void, pause: @escaping () -> Void) {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.playCommand.addTarget { _ in play(); return .success }
        center.pauseCommand.addTarget { _ in pause(); return .success }
        center.togglePlayPauseCommand.addTarget { _ in
            if BackgroundAudioKeeper.shared.isMetronomeRunning {
                pause()
            } else {
                play()
            }
            return .success
        }
    }
}
