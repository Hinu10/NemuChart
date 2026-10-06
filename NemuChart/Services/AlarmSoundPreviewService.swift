import AVFoundation

enum AlarmSoundSynthesizer {
    static let sampleRate = 44_100.0

    static func phraseDuration(_ sound: AlarmSoundChoice) -> Double {
        switch sound {
        case .birds: 1.4
        case .siren: 2.4
        case .klaxon: 0.8
        case .bell: 1.6
        case .voiceMorning, .voiceCountdown: 0.5
        case .system, .gentleChime: 1.0
        }
    }

    /// 1フレーズ分の波形。試聴とアラーム用音源で同じ音を使う。声の音源では台詞の前に鳴らす合図音になる。
    static func phrase(_ sound: AlarmSoundChoice) -> [Float] {
        let duration = phraseDuration(sound)
        let frameCount = Int(sampleRate * duration)
        var phase = 0.0
        return (0..<frameCount).map { frame in
            let time = Double(frame) / sampleRate
            let attack = min(1, time / 0.02)
            let release = max(0, 1 - time / duration)
            let value: Double
            switch sound {
            case .system:
                value = sin(2 * .pi * 880 * time) * min(1, time / 0.04) * release * 0.18
            case .gentleChime:
                let frequency = time < 0.45 ? 659.25 : 783.99
                value = sin(2 * .pi * frequency * time) * min(1, time / 0.04) * release * 0.18
            case .birds:
                let frequency = 1_300 + 500 * sin(time * 22)
                let pulse = max(0, sin(time * 10 * .pi))
                value = sin(2 * .pi * frequency * time) * min(1, time / 0.04) * release * pulse * 0.18
            case .siren:
                // 上下に揺れるウェイル音。倍音を足して耳につく音にする。
                let frequency = 1_050 + 450 * sin(2 * .pi * time / duration - .pi / 2)
                phase += 2 * .pi * frequency / sampleRate
                value = (sin(phase) + 0.35 * sin(3 * phase) + 0.2 * sin(5 * phase)) * attack * 0.22
            case .klaxon:
                // 「アーウーガ」と上がっていく警報。のこぎり波で太い音にする。
                let frequency = time < 0.6 ? 180 + 260 * (time / 0.6) : 0
                phase += 2 * .pi * frequency / sampleRate
                let saw = 2 * (phase / (2 * .pi) - floor(phase / (2 * .pi) + 0.5))
                value = time < 0.6 ? saw * attack * min(1, (0.6 - time) / 0.03) * 0.25 : 0
            case .bell:
                // ベルを小づちで連打するジリリ音。25Hzで鳴り・止みを繰り返す。
                let ring = time < 1.3 ? (sin(2 * .pi * 25 * time) > 0 ? 1.0 : 0.25) : 0
                value = (sin(2 * .pi * 2_350 * time) + 0.6 * sin(2 * .pi * 3_180 * time)) * ring * attack * 0.15
            case .voiceMorning, .voiceCountdown:
                // 台詞の前の「ピピッ」。
                let beep = (time < 0.12 || (time > 0.2 && time < 0.32)) ? 1.0 : 0
                value = sin(2 * .pi * 1_760 * time) * beep * 0.2
            }
            return Float(value)
        }
    }

    /// アラーム用に、フレーズ（声の音源では合図音＋台詞）と無音を繰り返した16bit PCMのWAVを作る。
    static func alarmWAV(_ sound: AlarmSoundChoice, speech: [Float] = [], totalDuration: Double = 25) -> Data {
        let phrase = phrase(sound) + speech
        let gap = [Float](repeating: 0, count: Int(sampleRate * (sound == .siren ? 0.1 : 0.6)))
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

    /// 任意のサンプルレートの音声を、線形補間で sampleRate に合わせる。
    static func resample(_ samples: [Float], from rate: Double) -> [Float] {
        guard rate > 0, rate != sampleRate, samples.count > 1 else { return samples }
        let ratio = rate / sampleRate
        let count = Int(Double(samples.count) / ratio)
        return (0..<count).map { index in
            let position = Double(index) * ratio
            let lower = Int(position)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(position - Double(lower))
            return samples[lower] * (1 - fraction) + samples[upper] * fraction
        }
    }
}

enum AlarmSpeechError: Error {
    case unavailable
}

/// 端末の読み上げ音声で台詞を波形にする。アプリに音声ファイルは同梱しない。
@MainActor
final class AlarmSpeechRenderer {
    private let synthesizer = AVSpeechSynthesizer()

    static func utterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 0.85
        utterance.volume = 1
        return utterance
    }

    func render(_ text: String) async throws -> [Float] {
        final class Collector { var samples: [Float] = []; var rate = 0.0; var finished = false }
        let collector = Collector()
        let samples: [Float] = await withCheckedContinuation { continuation in
            synthesizer.write(Self.utterance(text)) { buffer in
                guard !collector.finished else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                    collector.finished = true
                    continuation.resume(returning: AlarmSoundSynthesizer.resample(collector.samples, from: collector.rate))
                    return
                }
                collector.rate = pcm.format.sampleRate
                let frames = Int(pcm.frameLength)
                if let floats = pcm.floatChannelData?[0] {
                    collector.samples += UnsafeBufferPointer(start: floats, count: frames)
                } else if let ints = pcm.int16ChannelData?[0] {
                    collector.samples += UnsafeBufferPointer(start: ints, count: frames).map { Float($0) / Float(Int16.max) }
                }
            }
        }
        guard !samples.isEmpty else { throw AlarmSpeechError.unavailable }
        // 合成音と同じくらいの大きさにそろえる（WAV書き出し時に4倍される）。
        let peak = samples.map(abs).max() ?? 1
        return samples.map { $0 / max(peak, 0.001) * 0.24 }
    }
}

@MainActor
final class AlarmSoundPreviewService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let speaker = AVSpeechSynthesizer()

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    func play(_ sound: AlarmSoundChoice) throws {
        player.stop()
        speaker.stopSpeaking(at: .immediate)
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
        if let text = sound.speechText {
            let utterance = AlarmSpeechRenderer.utterance(text)
            utterance.preUtteranceDelay = AlarmSoundSynthesizer.phraseDuration(sound)
            speaker.speak(utterance)
        }
    }
}
