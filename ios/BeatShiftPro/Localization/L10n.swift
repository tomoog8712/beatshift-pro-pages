import Foundation

enum AppLang: String, CaseIterable {
    case jp = "JP"
    case en = "EN"
    case zh = "ZH"
    case ko = "KO"
    case es = "ES"
    case pt = "PT"

    static func from(locale: String) -> AppLang {
        let l = locale.lowercased()
        if l.hasPrefix("ja") { return .jp }
        if l.hasPrefix("zh") { return .zh }
        if l.hasPrefix("ko") { return .ko }
        if l.hasPrefix("es") { return .es }
        if l.hasPrefix("pt") { return .pt }
        return .en
    }

    static func detect() -> AppLang {
        let locale = Locale.preferredLanguages.first ?? "en"
        return from(locale: locale)
    }
}

struct L10nStrings {
    var tempo: String
    var swingTitle: String
    var soundClick: String
    var soundWoodblock: String
    var soundVoice: String
    var modalSoundTitle: String
    var swingBtnOff: String
    var swingBtn8th: String
    var swingBtn16th: String
    var cancel: String
    var modalBars: String
    var modalPrompt: String
    var tagSeq: String
    var tagCu: String
    var tagSpd: String
    var tagMod: String
    var tagOdd: String
    var deleteBtn: String
    var barsUnit: String
    var barProgress: String
    var currentLabel: String
    var cuMxGuide: String
    var cuMxPulse: String
    var spdStart: String
    var spdEnd: String
    var spdSec: String
    var spdVal: String
    var spdRhythmTitle: String
    var lblCount: String
    var lblOddSigSetting: String
    var modTrainOn: String
    var modTrainOff: String
    var modCycleUnit: String
    var modLabelGuide: String
    var modLabelAccent: String
    var modLabelNormal: String
    var modModalCycleTitle: String
    var notes: [String: String]
    var modeNames: [String]
}

enum L10n {
    static func strings(for lang: AppLang) -> L10nStrings {
        switch lang {
        case .jp:
            return L10nStrings(
                tempo: "TEMPO", swingTitle: "SWING RATIO",
                soundClick: "Sound: Click 🔊", soundWoodblock: "Sound: Woodblock 🪵", soundVoice: "Sound: Voice 🗣️",
                modalSoundTitle: "音色を選択",
                swingBtnOff: "SWING: OFF", swingBtn8th: "SWING: 8分", swingBtn16th: "SWING: 16分",
                cancel: "キャンセル", modalBars: "ループする小節数を選択", modalPrompt: "の保存名を入力してください:",
                tagSeq: "シーケンス", tagCu: "チェンジUP", tagSpd: "スピード", tagMod: "モジュレーション", tagOdd: "変拍子",
                deleteBtn: "削除", barsUnit: "小節", barProgress: "小節", currentLabel: "【 現在 】",
                cuMxGuide: "① 4/4 GUIDE", cuMxPulse: "② PULSE",
                spdStart: "開始BPM", spdEnd: "終了BPM", spdSec: "変化させる秒数", spdVal: "変化するBPM値",
                spdRhythmTitle: "カウントリズムを選択", lblCount: "カウント: ", lblOddSigSetting: "拍子設定: ",
                modTrainOn: "TRAINING: ON 🟢", modTrainOff: "TRAINING: OFF", modCycleUnit: "小節周期",
                modLabelGuide: "① GUIDE", modLabelAccent: "② A Accent", modLabelNormal: "③ A Normal",
                modModalCycleTitle: "消音・消える周期を選択",
                notes: jpNotes,
                modeNames: ["シーケンス", "チェンジアップ", "スピード", "変拍子", "モジュレーション"]
            )
        case .en:
            return L10nStrings(
                tempo: "TEMPO", swingTitle: "SWING RATIO",
                soundClick: "Sound: Click 🔊", soundWoodblock: "Sound: Woodblock 🪵", soundVoice: "Sound: Voice 🗣️",
                modalSoundTitle: "Select Sound",
                swingBtnOff: "SWING: OFF", swingBtn8th: "SWING: 8th", swingBtn16th: "SWING: 16th",
                cancel: "Cancel", modalBars: "Select Loop Bars", modalPrompt: "Enter config name:",
                tagSeq: "Sequence", tagCu: "ChangeUP", tagSpd: "Speed", tagMod: "Mod", tagOdd: "OddTime",
                deleteBtn: "Delete", barsUnit: "Bars", barProgress: "Bars", currentLabel: "[ Active ]",
                cuMxGuide: "① 4/4 GUIDE", cuMxPulse: "② PULSE",
                spdStart: "Start BPM", spdEnd: "End BPM", spdSec: "Pace (Seconds)", spdVal: "Pace (BPM Delta)",
                spdRhythmTitle: "Select Count Rhythm", lblCount: "Count: ", lblOddSigSetting: "Signatures: ",
                modTrainOn: "TRAINING: ON 🟢", modTrainOff: "TRAINING: OFF", modCycleUnit: "Bar Cycle",
                modLabelGuide: "① GUIDE", modLabelAccent: "② A Accent", modLabelNormal: "③ A Normal",
                modModalCycleTitle: "Select Mute Bar Cycle",
                notes: enNotes,
                modeNames: ["Sequence", "ChangeUp", "Speed", "Odd Time", "Modulation"]
            )
        case .zh:
            return L10nStrings(
                tempo: "速度", swingTitle: "摇摆比例",
                soundClick: "音色: 电子 🔊", soundWoodblock: "音色: 木鱼 🪵", soundVoice: "音色: 人声 🗣️",
                modalSoundTitle: "选择音色",
                swingBtnOff: "摇摆: 关闭", swingBtn8th: "摇摆: 8分", swingBtn16th: "摇摆: 16分",
                cancel: "取消", modalBars: "选择循环小节数", modalPrompt: "请输入配置名称:",
                tagSeq: "序列", tagCu: "切分", tagSpd: "速度", tagMod: "调制", tagOdd: "变拍",
                deleteBtn: "删除", barsUnit: "小节", barProgress: "小节", currentLabel: "【 当前 】",
                cuMxGuide: "① 4/4 引导", cuMxPulse: "② 脉冲",
                spdStart: "起始 BPM", spdEnd: "结束 BPM", spdSec: "变化时间 (秒)", spdVal: "变化步長 (BPM)",
                spdRhythmTitle: "选择计数节奏", lblCount: "节奏: ", lblOddSigSetting: "拍子设定: ",
                modTrainOn: "训练: 开启 🟢", modTrainOff: "训练: 关闭", modCycleUnit: "小节周期",
                modLabelGuide: "① 引导音", modLabelAccent: "② A 强音", modLabelNormal: "③ A 常音",
                modModalCycleTitle: "选择消音循环周期",
                notes: zhNotes,
                modeNames: ["序列节拍", "变速切分", "变速自动化", "变拍子", "时值调制"]
            )
        case .ko:
            return L10nStrings(
                tempo: "템포", swingTitle: "스윙 비율",
                soundClick: "사운드: 클릭 🔊", soundWoodblock: "사운드: 우드블록 🪵", soundVoice: "사운드: 음성 🗣️",
                modalSoundTitle: "사운드 선택",
                swingBtnOff: "스윙: OFF", swingBtn8th: "스윙: 8분", swingBtn16th: "스윙: 16분",
                cancel: "취소", modalBars: "루프할 마디 수 선택", modalPrompt: "저장할 구성 이름을 입력하세요:",
                tagSeq: "시퀀스", tagCu: "체인지업", tagSpd: "스피드", tagMod: "모듈레이션", tagOdd: "변박자",
                deleteBtn: "삭제", barsUnit: "마디", barProgress: "마디", currentLabel: "[ 사용 중 ]",
                cuMxGuide: "① 4/4 가이드", cuMxPulse: "② 펄스",
                spdStart: "시작 BPM", spdEnd: "종료 BPM", spdSec: "변화 시간(초)", spdVal: "변화할 BPM 폭",
                spdRhythmTitle: "카운트 리듬 선택", lblCount: "카운트: ", lblOddSigSetting: "박자 설정: ",
                modTrainOn: "트레이닝: 켜짐 🟢", modTrainOff: "트레이닝: 꺼짐", modCycleUnit: "마디 주기",
                modLabelGuide: "① 가이드", modLabelAccent: "② A 악센트", modLabelNormal: "③ A 일반음",
                modModalCycleTitle: "뮤트 소정 주기 선택",
                notes: koNotes,
                modeNames: ["시퀀스", "체인지업", "스피드 오토메이션", "변박자", "모듈레이션"]
            )
        case .es:
            return L10nStrings(
                tempo: "TEMPO", swingTitle: "RATIO DE SWING",
                soundClick: "Sonido: Click 🔊", soundWoodblock: "Sonido: Bloque 🪵", soundVoice: "Sonido: Voz 🗣️",
                modalSoundTitle: "Seleccionar Sonido",
                swingBtnOff: "SWING: OFF", swingBtn8th: "SWING: 8th", swingBtn16th: "SWING: 16th",
                cancel: "Cancelar", modalBars: "Seleccionar Compases", modalPrompt: "Nombre de configuración:",
                tagSeq: "Secuencia", tagCu: "ChangeUP", tagSpd: "Progreso", tagMod: "Mod", tagOdd: "Ímpar",
                deleteBtn: "Eliminar", barsUnit: "Compases", barProgress: "Compases", currentLabel: "[ Activo ]",
                cuMxGuide: "① 4/4 GUÍA", cuMxPulse: "② PULSO",
                spdStart: "BPM Inicial", spdEnd: "BPM Final", spdSec: "Intervalo (Segundos)", spdVal: "Incremento (BPM)",
                spdRhythmTitle: "Ritmo de Conteo", lblCount: "Conteo: ", lblOddSigSetting: "Ajuste de Compás: ",
                modTrainOn: "ENTRENAR: SÍ 🟢", modTrainOff: "ENTRENAR: NO", modCycleUnit: "Ciclo de Compases",
                modLabelGuide: "① GUÍA", modLabelAccent: "② A Acento", modLabelNormal: "③ A Normal",
                modModalCycleTitle: "Seleccionar Ciclo de Silencio",
                notes: esNotes,
                modeNames: ["Secuencia", "ChangeUp", "Aceleración", "Ritmo Irregular", "Modulación"]
            )
        case .pt:
            return L10nStrings(
                tempo: "ANDAMENTO", swingTitle: "PROPORÇÃO SWING",
                soundClick: "Som: Click 🔊", soundWoodblock: "Som: Bloco 🪵", soundVoice: "Som: Voz 🗣️",
                modalSoundTitle: "Selecionar Som",
                swingBtnOff: "SWING: OFF", swingBtn8th: "SWING: 8th", swingBtn16th: "SWING: 16th",
                cancel: "Cancelar", modalBars: "Selecionar Compassos", modalPrompt: "Nome da configuração:",
                tagSeq: "Sequência", tagCu: "ChangeUP", tagSpd: "Aceleração", tagMod: "Mod", tagOdd: "Tempo Ímpar",
                deleteBtn: "Excluir", barsUnit: "Compassos", barProgress: "Compassos", currentLabel: "[ Active ]",
                cuMxGuide: "① 4/4 GUIA", cuMxPulse: "② PULSO",
                spdStart: "BPM Inicial", spdEnd: "BPM Final", spdSec: "Tempo (Segundos)", spdVal: "Aumento (BPM)",
                spdRhythmTitle: "Ritmo de Contagem", lblCount: "Contagem: ", lblOddSigSetting: "Configurar Compasso: ",
                modTrainOn: "TREINAR: SIM 🟢", modTrainOff: "TREINAR: NÃO", modCycleUnit: "Ciclo de Compassos",
                modLabelGuide: "① GUIA", modLabelAccent: "② A Acento", modLabelNormal: "③ A Normal",
                modModalCycleTitle: "Selecionar Ciclo de Mute",
                notes: ptNotes,
                modeNames: ["Sequência", "ChangeUp", "Aceleração", "Tempo Ímpar", "Modulação"]
            )
        }
    }

    private static let jpNotes: [String: String] = [
        "全音符": "全音符", "2分音符": "2分音符", "4拍3連": "4拍3連", "4分音符": "4分音符",
        "4拍5連": "4拍5連", "2拍3連": "2拍3連", "4拍7連": "4拍7連", "8分音符": "8分音符",
        "4拍9連": "4拍9連", "2拍5連": "2拍5連", "3連符": "3連符", "2拍7連符": "2拍7連符",
        "16分音符": "16分音符", "6連符": "6連符", "32分音符": "32分音符",
        "16分3つ割り": "16分3つ割り", "16分5つ割り": "16分5つ割り", "16分7つ割り": "16分7つ割り",
        "8分3つ割り": "8分3つ割り", "8分5つ割り": "8分5つ割り", "8分7つ割り": "8分7つ割り",
        "3連4つ割り": "3連4つ割り", "3連5つ割り": "3連5つ割り", "3連7つ割り": "3連7つ割り"
    ]

    private static let enNotes: [String: String] = [
        "全音符": "Whole", "2分音符": "Half", "4拍3連": "3 Over 4", "4分音符": "Quarter",
        "4拍5連": "5 Over 4", "2拍3連": "3 Over 2", "4拍7連": "7 Over 4", "8分音符": "8th",
        "4拍9連": "9 Over 4", "2拍5連": "5 Over 2", "3連符": "Triplet", "2拍7連符": "7 Over 2",
        "16分音符": "16th", "6連符": "Sextuplet", "32分音符": "32nd",
        "16分3つ割り": "16th Div-3", "16分5つ割り": "16th Div-5", "16分7つ割り": "16th Div-7",
        "8分3つ割り": "8th Div-3", "8分5つ割り": "8th Div-5", "8分7つ割り": "8th Div-7",
        "3連4つ割り": "Triplet Div-4", "3連5つ割り": "Triplet Div-5", "3連7つ割り": "Triplet Div-7"
    ]

    private static let zhNotes: [String: String] = [
        "全音符": "全音符", "2分音符": "二分音符", "4拍3連": "4拍3连", "4分音符": "四分音符",
        "4拍5連": "4拍5连", "2拍3連": "2拍3连", "4拍7連": "4拍7连", "8分音符": "八分音符",
        "4拍9連": "4拍9连", "2拍5連": "2拍5连", "3連符": "三连音", "2拍7連符": "2拍7连音",
        "16分音符": "十六分音符", "6連符": "六连音", "32分音符": "三十二分音符",
        "16分3つ割り": "16音符3打", "16分5つ割り": "16音符5打", "16分7つ割り": "16音符7打",
        "8分3つ割り": "8音符3打", "8分5つ割り": "8音符5打", "8分7つ割り": "8音符7打",
        "3連4つ割り": "三连音4打", "3連5つ割り": "三连音5打", "3連7つ割り": "三连音7打"
    ]

    private static let koNotes: [String: String] = [
        "全音符": "온음표", "2分音符": "2분음표", "4拍3連": "4박 3연음", "4分音符": "4분음표",
        "4拍5連": "4박 5연음", "2拍3連": "2박 3연음", "4拍7連": "4박 7연음", "8分音符": "8분음표",
        "4拍9連": "4박 9연음", "2拍5連": "2박 5연음", "3連符": "셋잇단음표", "2拍7連符": "2박 7연음",
        "16分音符": "16분음표", "6連符": "6연음", "32分音符": "32분음표",
        "16分3つ割り": "16분음표 3연묶음", "16分5つ割り": "16분음표 5연묶음", "16分7つ割り": "16분음표 7연묶음",
        "8分3つ割り": "8분음표 3연묶음", "8分5つ割り": "8분음표 5연묶음", "8分7つ割り": "8분음표 7연묶음",
        "3連4つ割り": "셋잇단음표 4연묶음", "3連5つ割り": "셋잇단음표 5연묶음", "3連7つ割り": "셋잇단음표 7연묶음"
    ]

    private static let esNotes: [String: String] = [
        "全音符": "Redonda", "2分音符": "Blanca", "4拍3連": "3 sobre 4", "4分音符": "Negra",
        "4拍5連": "5 sobre 4", "2拍3連": "3 sobre 2", "4拍7連": "7 sobre 4", "8分音符": "Corchea",
        "4拍9連": "9 sobre 4", "2拍5連": "5 sobre 2", "3連符": "Tresillo", "2拍7連符": "7 sobre 2",
        "16分音符": "Semicorchea", "6連符": "Sextillo", "32分音符": "Fusa",
        "16分3つ割り": "Semicorchea Grupo-3", "16分5つ割り": "Semicorchea Grupo-5", "16分7つ割り": "Semicorchea Grupo-7",
        "8分3つ割り": "Corchea Grupo-3", "8分5つ割り": "Corchea Grupo-5", "8分7つ割り": "Corchea Grupo-7",
        "3連4つ割り": "Tresillo Grupo-4", "3連5つ割り": "Tresillo Grupo-5", "3連7つ割り": "Tresillo Grupo-7"
    ]

    private static let ptNotes: [String: String] = [
        "全音符": "Semibreve", "2分音符": "Mínima", "4拍3連": "3 sobre 4", "4分音符": "Semínima",
        "4拍5連": "5 sobre 4", "2拍3連": "3 sobre 2", "4拍7連": "7 sobre 4", "8分音符": "Colcheia",
        "4拍9連": "9 sobre 4", "2拍5連": "5 sobre 2", "3連符": "Quiáltera", "2拍7連符": "7 sobre 2",
        "16分音符": "Semicolcheia", "6連符": "Sestina", "32分音符": "Fusa",
        "16分3つ割り": "Semicolcheia Grupo-3", "16分5つ割り": "Semicolcheia Grupo-5", "16分7つ割り": "Semicolcheia Grupo-7",
        "8分3つ割り": "Colcheia Grupo-3", "8分5つ割り": "Colcheia Grupo-5", "8分7つ割り": "Colcheia Grupo-7",
        "3連4つ割り": "Quiáltera Grupo-4", "3連5つ割り": "Quiáltera Grupo-5", "3連7つ割り": "Quiáltera Grupo-7"
    ]
}
