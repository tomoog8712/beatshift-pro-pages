# BeatShift Pro — iOS (Xcode)

既存の `app/`（単一HTMLアプリ）を WKWebView で包んだネイティブ殻です。

## 開く

```bash
open ios/BeatShiftPro.xcodeproj
```

## 初回セットアップ（Xcode）

1. プロジェクト設定 → **Signing & Capabilities**
2. **Team** に Apple Developer アカウントを選択
3. Bundle ID `com.beatshift.pro` が未使用か確認（衝突したら変更）
4. 実機またはシミュレータで Run

`app/index.html` や WAV を更新したら、ビルド時に `sync-webroot.sh` が自動同期します。手動同期:

```bash
./ios/sync-webroot.sh
```

## App Store 提出前に必要なもの

- [ ] Apple Developer Program（有料）加入
- [ ] App Icon（1024×1024）を `Assets.xcassets/AppIcon` に追加
- [ ] Bundle ID / 表示名・カテゴリ確定
- [ ] App Store Connect でアプリ登録・スクリーンショット・説明文
- [ ] 実機で音声（サイレントスイッチ ON / バックグラウンド）確認

## 構成

| パス | 役割 |
|------|------|
| `BeatShiftPro/WebViewContainer.swift` | ローカル HTML 読み込み |
| `BeatShiftPro/BeatShiftProApp.swift` | 起動・AVAudioSession |
| `BeatShiftPro/WebRoot/` | `app/` の同期コピー（バンドル用） |
| `sync-webroot.sh` | 同期スクリプト |
