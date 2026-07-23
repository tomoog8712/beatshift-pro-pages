import SwiftUI
import UIKit

/*
 Google Mobile Ads (AdMob) — SPM 組み込み手順
 --------------------------------------------
 1. Xcode でプロジェクトを開く
 2. File → Add Package Dependencies…
 3. URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
 4. Dependency Rule: Up to Next Major Version（推奨）
 5. Product: GoogleMobileAds を BeatShiftPro ターゲットに追加
 6. Info.plist に GADApplicationIdentifier を追加（本番 App ID）
 */

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdMobConfig {
    /// 本番バナー Ad Unit ID
    static let bannerAdUnitID = "ca-app-pub-8262880726701626/1891699530"
    /// 本番 App ID（Info.plist の GADApplicationIdentifier と一致）
    static let applicationID = "ca-app-pub-8262880726701626~8241605605"
    static let bannerHeight: CGFloat = 50
}

/// SwiftUI ラッパー。実機/シミュレータでは AdMob バナー、Preview / SDK未導入時はダミー表示。
struct AdBannerView: View {
    var adUnitID: String = AdMobConfig.bannerAdUnitID
    /// Preview / Canvas では常にプレースホルダーを出す
    var forcePlaceholder: Bool = false

    var body: some View {
        Group {
            if forcePlaceholder {
                AdBannerPlaceholder()
            } else {
                #if canImport(GoogleMobileAds)
                AdBannerRepresentable(adUnitID: adUnitID)
                #else
                AdBannerPlaceholder()
                #endif
            }
        }
        .frame(height: AdMobConfig.bannerHeight)
        .frame(maxWidth: .infinity)
        .background(Theme.bgElevated)
    }
}

struct AdBannerPlaceholder: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.surface)
            Rectangle()
                .stroke(Theme.border, lineWidth: 1)
            Text("[ 広告エリア ]")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("広告エリア（プレースホルダー）")
    }
}

#if canImport(GoogleMobileAds)
/// GADBannerView を SwiftUI に載せる
struct AdBannerRepresentable: UIViewControllerRepresentable {
    var adUnitID: String

    func makeUIViewController(context: Context) -> BannerAdViewController {
        BannerAdViewController(adUnitID: adUnitID)
    }

    func updateUIViewController(_ uiViewController: BannerAdViewController, context: Context) {
        uiViewController.adUnitID = adUnitID
        uiViewController.reloadIfNeeded()
    }
}

final class BannerAdViewController: UIViewController, BannerViewDelegate {
    var adUnitID: String
    private var bannerView: BannerView?
    private var isLoading = false
    private var retryCount = 0
    private let maxRetries = 4

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.bgElevated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let bannerView {
            bannerView.adSize = currentAdSize()
        }
    }

    func reloadIfNeeded() {
        guard view.window != nil else { return }
        if bannerView == nil {
            loadBanner()
        }
    }

    private func currentAdSize() -> AdSize {
        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }

    private func loadBanner() {
        if isLoading { return }
        isLoading = true

        let banner = bannerView ?? BannerView(adSize: currentAdSize())
        banner.adUnitID = adUnitID
        banner.rootViewController = self
        banner.delegate = self
        banner.adSize = currentAdSize()

        if bannerView == nil {
            banner.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                banner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                banner.heightAnchor.constraint(equalToConstant: AdMobConfig.bannerHeight)
            ])
            bannerView = banner
        }

        banner.load(Request())
    }

    private func scheduleRetry() {
        guard retryCount < maxRetries else { return }
        retryCount += 1
        let delay = Double(retryCount) * 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.isLoading = false
            self?.loadBanner()
        }
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoading = false
        retryCount = 0
        NSLog("BeatShiftPro AdMob: banner loaded")
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        isLoading = false
        NSLog("BeatShiftPro AdMob: banner failed — \(error.localizedDescription)")
        scheduleRetry()
    }
}
#endif

#if DEBUG
#Preview("Ad Banner Placeholder") {
    VStack {
        Spacer()
        AdBannerView(forcePlaceholder: true)
    }
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
#endif
