import AVFoundation

@MainActor
final class AlarmSoundPreviewService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    func play(_ sound: AlarmSoundChoice) throws {
        player.stop()
        let sampleRate = 44_100.0
        let duration = sound == .birds ? 1.4 : 1.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let frequency: Double
            switch sound {
            case .system: frequency = 880
            case .gentleChime: frequency = time < 0.45 ? 659.25 : 783.99
            case .birds: frequency = 1_300 + 500 * sin(time * 22)
            }
            let attack = min(1, time / 0.04)
            let release = max(0, 1 - time / duration)
            let pulse = sound == .birds ? max(0, sin(time * 10 * .pi)) : 1
            samples[frame] = Float(sin(2 * .pi * frequency * time) * attack * release * pulse * 0.18)
        }

        if !engine.isRunning { try engine.start() }
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }
}
