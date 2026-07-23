import SwiftUI

struct ModalSheet: View {
    let kind: BeatShiftStore.ModalKind
    @ObservedObject var store: BeatShiftStore
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                switch kind {
                case .sound:
                    ForEach(SoundType.allCases, id: \.rawValue) { s in
                        Button(soundLabel(s)) {
                            store.soundType = s
                            dismiss()
                        }
                    }
                case .bars:
                    ForEach(1...8, id: \.self) { i in
                        Button("\(i) \(store.l10n.barsUnit)") {
                            store.maxBarsPerPattern = i
                            store.refreshCuLabels()
                            dismiss()
                        }
                    }
                case .speedBpm(let isStart):
                    ForEach(Array(stride(from: 20, through: 240, by: 10)), id: \.self) { b in
                        Button("\(b) BPM") {
                            if isStart { store.spdStartBpm = b } else { store.spdEndBpm = b }
                            if !store.isRunning { store.syncSpeedBpmDisplay() }
                            dismiss()
                        }
                    }
                case .speedPace(let isSec):
                    if isSec {
                        ForEach([0.2, 0.3, 0.5, 0.7, 1, 2, 3, 4, 5], id: \.self) { s in
                            Button(s == floor(s) ? "\(Int(s)) 秒" : String(format: "%.1f 秒", s)) {
                                store.spdStepSec = s
                                dismiss()
                            }
                        }
                    } else {
                        ForEach(1...10, id: \.self) { i in
                            Button("\(i) BPM") {
                                store.spdStepBpm = i
                                dismiss()
                            }
                        }
                    }
                case .speedRhythm:
                    ForEach(RhythmType.spdRhythmPool.indices, id: \.self) { idx in
                        let key = RhythmType.spdRhythmPool[idx]
                        Button(store.l10n.notes[key] ?? key) {
                            store.spdRhythmIndex = idx
                            dismiss()
                        }
                    }
                case .oddSig:
                    ForEach(["5/4", "7/8", "9/8"], id: \.self) { sig in
                        Button(sig) {
                            store.applyOddPreset(sig)
                            dismiss()
                        }
                        .foregroundStyle(sig == store.oddSignatureKey ? Theme.accentOrange : Theme.text)
                    }
                case .modMatrix:
                    ForEach(RhythmType.modMatrixPool.indices, id: \.self) { idx in
                        let key = RhythmType.modMatrixPool[idx]
                        Button(store.l10n.notes[key] ?? key) {
                            store.modMatrixIndex = idx
                            store.applyModSwingConstraints()
                            dismiss()
                        }
                    }
                case .modCycle:
                    ForEach([1, 2, 4, 8], id: \.self) { c in
                        Button("\(c) \(store.l10n.modCycleUnit)") {
                            store.modTrainingCycleBars = c
                            dismiss()
                        }
                    }
                case .setlist:
                    Button("➕ 現在の設定をこのリストに保存") {
                        store.saveNameDraft = "Pattern \(store.setlist.count + 1)"
                        store.modal = .savePrompt
                    }
                    if store.setlist.isEmpty {
                        Text("保存された設定はありません")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(Array(store.setlist.enumerated()), id: \.element.id) { idx, item in
                        HStack {
                            Button {
                                store.loadSetlistItem(item)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tag(for: item.mode))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                    Text("\(item.name) (BPM:\(item.bpm))")
                                        .foregroundStyle(Theme.text)
                                }
                            }
                            Spacer()
                            Button(store.l10n.deleteBtn) {
                                store.deleteSetlist(at: idx)
                            }
                            .foregroundStyle(Theme.accentPink)
                        }
                    }
                case .savePrompt:
                    TextField(store.l10n.modalPrompt, text: $store.saveNameDraft)
                    Button("Save") {
                        let name = store.saveNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            store.saveCurrentConfig(name: name)
                        }
                        store.modal = .setlist
                    }
                case .settings:
                    removeAdsSettingsSection
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.l10n.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents(kind == .settings ? [.medium] : [.medium, .large])
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var removeAdsSettingsSection: some View {
        Section {
            if storeManager.isAdRemoved {
                Text("バナー広告は非表示です。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button {
                    Task { await storeManager.purchaseRemoveAds() }
                } label: {
                    HStack {
                        Text(storeManager.purchaseButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        if storeManager.isPurchasing {
                            ProgressView()
                        }
                    }
                }
                .disabled(storeManager.isPurchasing)

                Button {
                    Task { await storeManager.restorePurchases() }
                } label: {
                    HStack {
                        Text("購入を復元（Restore）")
                        Spacer()
                        if storeManager.isRestoring {
                            ProgressView()
                        }
                    }
                }
                .disabled(storeManager.isRestoring)
            }
        } header: {
            Text("広告")
        } footer: {
            if !storeManager.isAdRemoved {
                Text("買い切り（一度の購入で広告を永久に非表示）。プロダクト ID: \(StoreManager.removeAdsProductID)")
                    .font(.system(size: 11))
            }
        }
    }

    private var title: String {
        switch kind {
        case .sound: return store.l10n.modalSoundTitle
        case .bars: return store.l10n.modalBars
        case .setlist: return "再生リスト (Saved List)"
        case .savePrompt: return store.l10n.modalPrompt
        case .settings: return "設定"
        case .speedBpm(let s): return s ? store.l10n.spdStart : store.l10n.spdEnd
        case .speedPace(let s): return s ? store.l10n.spdSec : store.l10n.spdVal
        case .speedRhythm: return store.l10n.spdRhythmTitle
        case .oddSig: return store.l10n.lblOddSigSetting
        case .modMatrix: return store.lang == .jp ? "時値分割設定を選択" : "Select Modulation Matrix"
        case .modCycle: return store.l10n.modModalCycleTitle
        }
    }

    private func soundLabel(_ s: SoundType) -> String {
        switch s {
        case .click: return store.l10n.soundClick
        case .woodblock: return store.l10n.soundWoodblock
        case .voice: return store.l10n.soundVoice
        }
    }

    private func tag(for mode: String) -> String {
        switch mode {
        case "Normal": return store.l10n.tagSeq
        case "ChangeUp": return store.l10n.tagCu
        case "Speed": return store.l10n.tagSpd
        case "OddTime": return store.l10n.tagOdd
        case "Modulation": return store.l10n.tagMod
        default: return mode
        }
    }
}
