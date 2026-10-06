import AVFoundation

enum AlarmSoundSynthesizer {
    static let sampleRate = 44_100.0

    static func phraseDuration(_ sound: AlarmSoundChoice) -> Double { sound == .birds ? 1.4 : 1.0 }

    /// 1フレーズ分の波形。試聴とアラーム用音源で同じ音を使う。
    static func phrase(_ sound: AlarmSoundChoice) -> [Float] {
        let duration = phraseDuration(sound)
        let frameCount = Int(sampleRate * duration)
        return (0..<frameCount).map { frame in
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
            return Float(sin(2 * .pi * frequency * time) * attack * release * pulse * 0.18)
        }
    }

    /// アラーム用に、フレーズと無音を繰り返した16bit PCMのWAVを作る。
    static func alarmWAV(_ sound: AlarmSoundChoice, totalDuration: Double = 25) -> Data {
        let phrase = phrase(sound)
        let gap = [Float](repeating: 0, count: Int(sampleRate * 0.6))
        var samples: [Float] = []
        let target = Int(sampleRate * totalDuration)
        while samples.count < target { samples += phrase + gap }
        let pcm = samples.prefix(target).map { Int16(max(-1, min(1, $0 * 4)) * Float(Int16.max)) }

        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(pcm.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36) + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate) * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        pcm.forEach { append($0) }
        return data
    }
}

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
        let values = AlarmSoundSynthesizer.phrase(sound)
        let format = AVAudioFormat(standardFormatWithSampleRate: AlarmSoundSynthesizer.sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(values.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        for (index, value) in values.enumerated() { samples[index] = value }

        if !engine.isRunning { try engine.start() }
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }
}
