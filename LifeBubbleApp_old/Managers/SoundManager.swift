//
//  SoundManager.swift
//  LifeBubble
//
//  声音管理器 - 音效播放与反馈
//

import AVFoundation
import SwiftUI

class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    @Published var isSoundEnabled: Bool = true

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }

    /// 播放音效
    func play(_ soundName: String, volume: Float = 1.0) {
        guard isSoundEnabled else { return }

        // 如果音效文件不存在，则跳过（开发阶段预留）
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("⚠️ 音效文件未找到: \(soundName).mp3（已预留）")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()

            audioPlayers[soundName] = player
        } catch {
            print("音效播放失败: \(error)")
        }
    }

    /// 停止音效
    func stop(_ soundName: String) {
        audioPlayers[soundName]?.stop()
        audioPlayers[soundName] = nil
    }

    /// 停止所有音效
    func stopAll() {
        audioPlayers.values.forEach { $0.stop() }
        audioPlayers.removeAll()
    }
}

// MARK: - 音效预设
extension SoundManager {
    /// 泡泡破裂音效（清脆、湿润）
    func playBubblePop() {
        play("pop", volume: 0.7)
    }

    /// 泡泡创建音效（柔和、空灵）
    func playBubbleCreate() {
        play("create", volume: 0.5)
    }

    /// 转场音效（梦幻、流畅）
    func playTransition() {
        play("transition", volume: 0.6)
    }

    /// 完成任务音效（温暖、鼓励）
    func playComplete() {
        play("complete", volume: 0.8)
    }
}

// MARK: - 触觉反馈扩展
extension SoundManager {
    /// 轻微触觉反馈
    static func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// 中等触觉反馈
    static func hapticMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// 强烈触觉反馈
    static func hapticHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// 成功反馈
    static func hapticSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
