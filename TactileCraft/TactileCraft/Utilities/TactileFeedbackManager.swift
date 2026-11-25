import UIKit
import AudioToolbox

/// 拟物触觉与音效集中管理器
final class TactileFeedbackManager {
    static let shared = TactileFeedbackManager()

    var isSoundEnabled: Bool = true
    var isHapticsEnabled: Bool = true

    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let selectionHaptic = UISelectionFeedbackGenerator()

    private init() {
        rigidHaptic.prepare()
        heavyHaptic.prepare()
        softHaptic.prepare()
        selectionHaptic.prepare()
    }

    // MARK: - 打字机效果
    /// 敲击按键
    func playTypewriterKeyStrike() {
        if isHapticsEnabled {
            rigidHaptic.impactOccurred(intensity: 0.85)
        }
        if isSoundEnabled {
            // 系统击键音 1104
            AudioServicesPlaySystemSound(1104)
        }
    }

    /// 回车换行打字机叮铃声
    func playTypewriterCarriageReturn() {
        if isHapticsEnabled {
            mediumHaptic.impactOccurred(intensity: 1.0)
        }
        if isSoundEnabled {
            // 经典复古铃铛声/提醒音
            AudioServicesPlaySystemSound(1025)
        }
    }

    // MARK: - 滚轮信封效果
    /// 滚轮切换信封卡片
    func playRolodexTick() {
        if isHapticsEnabled {
            selectionHaptic.selectionChanged()
        }
        if isSoundEnabled {
            // 微弱滚轮咔哒声
            AudioServicesPlaySystemSound(1105)
        }
    }

    // MARK: - 打印机与撕纸效果
    /// 步进打印电机微脉冲
    func playPrinterStep() {
        if isHapticsEnabled {
            softHaptic.impactOccurred(intensity: 0.6)
        }
    }

    /// 撕纸断裂重震
    func playTearOffPaper() {
        if isHapticsEnabled {
            heavyHaptic.impactOccurred(intensity: 1.0)
        }
        if isSoundEnabled {
            // 脆响提示音
            AudioServicesPlaySystemSound(1106)
        }
    }
}
