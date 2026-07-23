import Foundation
import SwiftUI

/// 初起動から一定時間後に評価バナーを出す。一度閉じたら再表示しない。
@MainActor
final class AppReviewPromptController: ObservableObject {
    static let firstLaunchKey = "appReview.firstLaunchAt"
    static let dismissedKey = "appReview.bannerDismissed"
    /// 初起動からの待ち時間（秒）
    static let delayAfterFirstLaunch: TimeInterval = 120

    @Published private(set) var isBannerVisible = false

    private var showTask: Task<Void, Never>?

    init() {
        ensureFirstLaunchRecorded()
        scheduleIfNeeded()
    }

    func ensureFirstLaunchRecorded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.firstLaunchKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Self.firstLaunchKey)
        }
    }

    func scheduleIfNeeded() {
        showTask?.cancel()
        guard !UserDefaults.standard.bool(forKey: Self.dismissedKey) else {
            isBannerVisible = false
            return
        }

        let first = UserDefaults.standard.double(forKey: Self.firstLaunchKey)
        guard first > 0 else { return }

        let elapsed = Date().timeIntervalSince1970 - first
        let remaining = max(0, Self.delayAfterFirstLaunch - elapsed)

        showTask = Task { [weak self] in
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                guard !UserDefaults.standard.bool(forKey: Self.dismissedKey) else { return }
                self.isBannerVisible = true
            }
        }
    }

    func dismissPermanently() {
        UserDefaults.standard.set(true, forKey: Self.dismissedKey)
        isBannerVisible = false
        showTask?.cancel()
    }
}

struct AppReviewBannerView: View {
    var onRate: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("アプリの評価をお願いします")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("ご意見が今後の改善につながります")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 4)
            Button(action: onRate) {
                Text("評価する")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.surfaceRaised)
                    .clipShape(Circle())
            }
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
