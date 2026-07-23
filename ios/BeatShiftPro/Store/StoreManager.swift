import Foundation
import StoreKit

/*
 StoreKit Configuration（ローカル課金テスト）手順
 -----------------------------------------------
 1. ios/Products.storekit を使用
    （プロダクト ID: com.beatshift.pro.removeads / 非消耗型 / ¥600）
 2. Xcode → Product → Scheme → Edit Scheme… → Run → Options
 3. 「StoreKit Configuration」で Products.storekit が選ばれていることを確認
    （赤文字や None なら Products.storekit を選び直す）
 4. アプリを一度 Stop してから、Xcode の Run で再起動（必須）
 5. 設定 →「広告を非表示」で購入シートが出れば OK
 6. Debug → StoreKit → Manage Transactions… で購入リセット可能

 注意:
 - Configuration 未選択だと Product.products が空になり、
   「商品情報を取得できませんでした」と表示されます
 - Configuration 選択中は App Store Connect ではなくローカル定義が使われます
 - 本番提出前に App Store Connect で同一 Product ID の Non-Consumable を作成してください
 - 実機の Sandbox テスト時は Scheme の StoreKit Configuration を None にし、
   Sandbox Apple ID でサインインしてください
 */

@MainActor
final class StoreManager: ObservableObject {
    static let removeAdsProductID = "com.beatshift.pro.removeads"
    static let adRemovedDefaultsKey = "isAdRemoved"

    @Published private(set) var isAdRemoved: Bool {
        didSet {
            UserDefaults.standard.set(isAdRemoved, forKey: Self.adRemovedDefaultsKey)
        }
    }

    @Published private(set) var removeAdsProduct: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var alertMessage: String?

    private var transactionListener: Task<Void, Never>?

    /// 表示用。プロダクト未取得時は固定の ¥600 表記。
    var purchaseButtonTitle: String {
        if let price = removeAdsProduct?.displayPrice {
            return "広告を非表示（\(price)）"
        }
        return "広告を非表示（¥600）"
    }

    init() {
        isAdRemoved = UserDefaults.standard.bool(forKey: Self.adRemovedDefaultsKey)
        transactionListener = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            removeAdsProduct = products.first
            if products.isEmpty {
                NSLog("BeatShiftPro StoreKit: product not found — \(Self.removeAdsProductID)")
            }
        } catch {
            NSLog("BeatShiftPro StoreKit: loadProducts failed — \(error.localizedDescription)")
        }
    }

    func purchaseRemoveAds() async {
        if isAdRemoved { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            if removeAdsProduct == nil {
                await loadProducts()
            }
            guard let product = removeAdsProduct else {
                alertMessage = """
                商品情報を取得できませんでした。

                ・ネットワーク接続を確認してください
                ・しばらく待ってから再度お試しください
                ・改善しない場合は「購入を復元」も試してください

                ※ App Store 側でアプリ内課金が公開・有効になるまで数時間かかることがあります。
                """
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await applyEntitlement(from: transaction)
                await transaction.finish()
                alertMessage = "購入が完了しました。広告を非表示にしました。"
            case .userCancelled:
                break
            case .pending:
                alertMessage = "購入は保留中です。承認後に反映されます。"
            @unknown default:
                break
            }
        } catch {
            alertMessage = "購入に失敗しました: \(error.localizedDescription)"
        }
    }

    /// App Store と同期し、既存購入を再適用する
    func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if isAdRemoved {
                alertMessage = "購入を復元しました。広告は非表示です。"
            } else {
                alertMessage = "復元できる購入が見つかりませんでした。"
            }
        } catch {
            alertMessage = "復元に失敗しました: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                owned = true
                break
            }
        }
        // 確認できた場合のみ true にする（オフライン時にローカルフラグを消さない）
        if owned {
            isAdRemoved = true
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await applyEntitlement(from: transaction)
            await transaction.finish()
        }
    }

    private func applyEntitlement(from transaction: Transaction) async {
        guard transaction.productID == Self.removeAdsProductID else { return }
        if transaction.revocationDate == nil {
            isAdRemoved = true
        } else {
            isAdRemoved = false
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
