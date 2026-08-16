import AVFoundation
import AudioToolbox
import CoreHaptics
import SwiftUI
import UIKit
import HAWTPotatoCore

@MainActor
final class SensoryDirector {
    static let shared = SensoryDirector()

    private var engine: CHHapticEngine?
    private var pulseTimer: Timer?
    private var lastHeat: PotatoHeat?
    private var receiveActive = false
    private var countdownSound = false
    private var skin: PotatoSkin = .classic
    private var hapticsEnabled = true
    private var soundEnabled = true
    private var catchSoundID: SystemSoundID = 0
    private var tickSoundID: SystemSoundID = 0
    private var lastCatchAt: Date?
    private var lastCookedID: UUID?
    private var ticking = false
    private var tickTimer: Timer?
    private var fuseRemaining: TimeInterval = .greatestFiniteMagnitude
    private var enteredFinalThree = false
    private let tapGenerator = UIImpactFeedbackGenerator(style: .light)
    private let catchGenerator = UINotificationFeedbackGenerator()

    func prepare() {
        engine = try? CHHapticEngine()
        try? engine?.start()
        tapGenerator.prepare()
        catchGenerator.prepare()
        if let url = Bundle.main.url(forResource: "PotatoCatch", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(url as CFURL, &catchSoundID)
        }
        if let url = Bundle.main.url(forResource: "FuseTick", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(url as CFURL, &tickSoundID)
        }
        try? AVAudioSession.sharedInstance().setCategory(.soloAmbient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func sync(settings: AppSettings) {
        hapticsEnabled = settings.haptics
        soundEnabled = settings.soundEffects
        countdownSound = settings.countdownSounds
        if !countdownSound { stopTicking() }
    }

    func syncFuse(remaining: TimeInterval, countdownSound: Bool) {
        self.countdownSound = countdownSound
        fuseRemaining = remaining
        if remaining > 3 { enteredFinalThree = false }
        guard remaining > 0, remaining <= 10, countdownSound || (hapticsEnabled && remaining <= 3) else {
            stopTicking()
            return
        }
        if !ticking { startTicking() }
        if remaining <= 3, !enteredFinalThree {
            enteredFinalThree = true
            vibrateFinalThree()
        }
    }

    func buttonTap() {
        guard hapticsEnabled else { return }
        tapGenerator.impactOccurred(intensity: 0.9)
        tapGenerator.prepare()
    }

    func potatoCaught(sound: Bool? = nil, haptics: Bool? = nil) {
        if let lastCatchAt, Date.now.timeIntervalSince(lastCatchAt) < 0.55 { return }
        lastCatchAt = .now
        let playSound = sound ?? soundEnabled
        let playHaptics = haptics ?? hapticsEnabled
        if playSound, catchSoundID != 0 {
            if playHaptics {
                AudioServicesPlayAlertSound(catchSoundID)
            } else {
                AudioServicesPlaySystemSound(catchSoundID)
            }
        } else if playSound {
            AudioServicesPlaySystemSound(1007)
            if playHaptics {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        } else if playHaptics {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        guard playHaptics else { return }
        catchGenerator.notificationOccurred(.warning)
        catchGenerator.prepare()
        thud()
        play(intensity: 1.0, sharpness: 0.55, duration: 0.14, delay: 0.12)
        play(intensity: 0.75, sharpness: 0.3, duration: 0.16, delay: 0.26)
    }

    func theyAreCooked(cardID: UUID, isMe: Bool) {
        if lastCookedID == cardID { return }
        lastCookedID = cardID
        stopTicking()
        if soundEnabled {
            AudioServicesPlaySystemSound(1005)
        }
        guard hapticsEnabled else { return }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        catchGenerator.notificationOccurred(isMe ? .error : .warning)
        catchGenerator.prepare()
        thud()
        play(intensity: 1.0, sharpness: 0.7, duration: 0.18, delay: 0.12)
        play(intensity: 1.0, sharpness: 0.45, duration: 0.2, delay: 0.28)
        play(intensity: 0.85, sharpness: 0.25, duration: 0.22, delay: 0.48)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    func startReceivePulse(heat: PotatoHeat, haptics: Bool, countdownSound: Bool, skin: PotatoSkin = .classic) {
        stopHeartbeat()
        receiveActive = true
        self.countdownSound = countdownSound
        self.skin = skin
        guard haptics else { return }
        lastHeat = nil
        schedulePulse(heat)
    }

    func updateReceiveHeat(_ heat: PotatoHeat, haptics: Bool, countdownSound: Bool, skin: PotatoSkin = .classic) {
        guard receiveActive, haptics else { return }
        self.countdownSound = countdownSound
        self.skin = skin
        guard heat != lastHeat else { return }
        schedulePulse(heat)
    }

    func stopHeartbeat() {
        receiveActive = false
        pulseTimer?.invalidate()
        pulseTimer = nil
        lastHeat = nil
    }

    private func startTicking() {
        ticking = true
        playTick()
        scheduleTickTimer()
    }

    private func stopTicking() {
        ticking = false
        tickTimer?.invalidate()
        tickTimer = nil
        if fuseRemaining > 3 || fuseRemaining <= 0 {
            enteredFinalThree = false
        }
    }

    private func scheduleTickTimer() {
        tickTimer?.invalidate()
        let interval: TimeInterval = fuseRemaining <= 3 ? 0.5 : 1.0
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.ticking else { return }
                if self.fuseRemaining <= 0 {
                    self.stopTicking()
                    return
                }
                self.playTick()
                let needed: TimeInterval = self.fuseRemaining <= 3 ? 0.5 : 1.0
                if abs(needed - interval) > 0.05 {
                    self.scheduleTickTimer()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func playTick() {
        if countdownSound {
            if tickSoundID != 0 {
                AudioServicesPlaySystemSound(tickSoundID)
            } else {
                AudioServicesPlaySystemSound(1103)
            }
        }
        guard hapticsEnabled else { return }
        if fuseRemaining <= 3 {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            tapGenerator.impactOccurred(intensity: 1.0)
            play(intensity: 1.0, sharpness: 0.65, duration: 0.12)
        } else {
            tapGenerator.impactOccurred(intensity: 0.55)
        }
        tapGenerator.prepare()
    }

    private func vibrateFinalThree() {
        guard hapticsEnabled else { return }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        catchGenerator.notificationOccurred(.warning)
        catchGenerator.prepare()
        thud()
        play(intensity: 1.0, sharpness: 0.7, duration: 0.16)
    }

    private func schedulePulse(_ heat: PotatoHeat) {
        pulseTimer?.invalidate()
        let enteringDanger = (heat == .critical || heat == .finalCountdown) && lastHeat != heat
        lastHeat = heat
        pulse(heat)
        if countdownSound, enteringDanger {
            AudioServicesPlaySystemSound(1052)
        }
        let interval: TimeInterval
        switch heat {
        case .normal: interval = 1.35
        case .warming: interval = 0.95
        case .hot: interval = 0.62
        case .critical: interval = 0.34
        case .finalCountdown: interval = 0.16
        }
        let scaled = max(0.28, interval * PotatoBrain.pulseIntervalScale(for: skin))
        let timer = Timer(timeInterval: scaled, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pulse(heat)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pulseTimer = timer
    }

    private func pulse(_ heat: PotatoHeat) {
        guard receiveActive else { return }
        let intensity: Float
        let sharpness: Float
        switch heat {
        case .normal:
            intensity = 0.28
            sharpness = 0.2
        case .warming:
            intensity = 0.42
            sharpness = 0.28
        case .hot:
            intensity = 0.62
            sharpness = 0.4
        case .critical:
            intensity = 0.85
            sharpness = 0.55
        case .finalCountdown:
            intensity = 1.0
            sharpness = 0.7
        }
        let scale = PotatoBrain.hapticScale(for: skin)
        play(intensity: min(1, intensity * scale), sharpness: min(1, sharpness * scale), duration: heat == .finalCountdown ? 0.08 : 0.12)
    }

    private func thud() {
        play(intensity: 1.0, sharpness: 0.25, duration: 0.2)
    }

    private func play(intensity: Float, sharpness: Float, duration: TimeInterval, delay: TimeInterval = 0) {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: delay,
            duration: duration
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}

struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { SensoryDirector.shared.buttonTap() }
            }
    }
}

struct HapticPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { SensoryDirector.shared.buttonTap() }
            }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    static var haptic: HapticButtonStyle { HapticButtonStyle() }
}

extension ButtonStyle where Self == HapticPlainButtonStyle {
    static var hapticPlain: HapticPlainButtonStyle { HapticPlainButtonStyle() }
}
