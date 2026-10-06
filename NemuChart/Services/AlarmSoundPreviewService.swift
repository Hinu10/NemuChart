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
        case .melodyGentle: gentleMelody.duration
        case .melodyLoud: loudMelody.duration
        }
    }

    /// メロディー音源の譜面。note は MIDI ノート番号（72 = 高いド）、nil は休符。beats は拍数。
    struct Melody {
        let notes: [(note: Int?, beats: Double)]
        let secondsPerBeat: Double
        var duration: Double { notes.reduce(0) { $0 + $1.beats } * secondsPerBeat }
    }

    /// ミ・ソ・ドと上がって、ゆっくりドに戻る朝のメロディー。
    static let gentleMelody = Melody(notes: [
        (76, 1), (79, 1), (84, 2), (83, 1), (79, 1), (81, 2),
        (79, 1), (76, 1), (77, 1), (74, 1), (72, 4),
    ], secondsPerBeat: 0.28)

    /// 起床ラッパ風に駆け上がる速いファンファーレ。
    static let loudMelody = Melody(notes: [
        (67, 1), (72, 1), (76, 1), (79, 2), (76, 1), (79, 4), (nil, 1),
        (67, 1), (72, 1), (76, 1), (79, 2), (76, 1), (84, 4), (nil, 2),
    ], secondsPerBeat: 0.12)

    /// 1フレーズ分の波形。試聴とアラーム用音源で同じ音を使う。声の音源では台詞の前に鳴らす合図音になる。
    static func phrase(_ sound: AlarmSoundChoice) -> [Float] {
        switch sound {
        case .melodyGentle: return render(gentleMelody, loud: false)
        case .melodyLoud: return render(loudMelody, loud: true)
        default: break
        }
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
            case .melodyGentle, .melodyLoud:
                value = 0 // 上の render で作って返している。
            }
            return Float(value)
        }
    }

    /// 譜面を波形にする。やさしい音はオルゴールのように余韻を次の音へ重ね、うるさい音は倍音の多い音を短く切って弾ませる。
    private static func render(_ melody: Melody, loud: Bool) -> [Float] {
        var samples = [Float](repeating: 0, count: Int(sampleRate * melody.duration))
        var start = 0.0
        for (note, beats) in melody.notes {
            let length = beats * melody.secondsPerBeat
            defer { start += length }
            guard let note else { continue }
            let frequency = 440 * pow(2, Double(note - 69) / 12)
            let ring = loud ? length * 0.85 : 1.2
            let first = Int(start * sampleRate)
            let end = min(samples.count, first + Int(ring * sampleRate))
            for frame in first..<end {
                let time = Double(frame - first) / sampleRate
                let phase = 2 * .pi * frequency * time
                let value: Double
                if loud {
                    let envelope = min(1, time / 0.005) * min(1, (ring - time) / 0.01)
                    value = (sin(phase) + 0.5 * sin(2 * phase) + sin(3 * phase) / 3 + sin(5 * phase) / 5 + sin(7 * phase) / 7) * envelope
                } else {
                    let envelope = min(1, time / 0.005) * exp(-time * 3.5)
                    value = (sin(phase) + 0.3 * sin(2 * phase) + 0.08 * sin(4 * phase)) * envelope
                }
                samples[frame] += Float(value)
            }
        }
        // ほかの音とそろえる。うるさい音はWAV書き出し時の4倍でほぼ最大音量になる。
        let peak = max(samples.map(abs).max() ?? 1, 0.001)
        let target: Float = loud ? 0.25 : 0.16
        return samples.map { $0 / peak * target }
    }

    /// アラーム用に、フレーズ（声の音源では合図音＋台詞）と無音を繰り返した16bit PCMのWAVを作る。
    static func alarmWAV(_ sound: AlarmSoundChoice, speech: [Float] = [], totalDuration: Double = 25) -> Data {
        let phrase = phrase(sound) + speech
        let gapDuration = switch sound {
        case .siren, .melodyLoud: 0.1
        case .melodyGentle: 1.0
        default: 0.6
        }
        let gap = [Float](repeating: 0, count: Int(sampleRate * gapDuration))
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
    private let format = AVAudioFormat(standardFormatWithSampleRate: AlarmSoundSynthesizer.sampleRate, channels: 1)!

    init() {
        engine.attach(player)
        // 再生するバッファと同じ形式でつなぐ。形式が違うと scheduleBuffer で強制終了する。
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ sound: AlarmSoundChoice) throws {
        player.stop()
        speaker.stopSpeaking(at: .immediate)
        let values = AlarmSoundSynthesizer.phrase(sound)
        let frameCount = AVAudioFrameCount(values.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        for (index, value) in values.enumerated() { samples[index] = value }

        // 試聴はボタンを押したときだけなので、消音スイッチ中でも聞こえるようにする。
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try session.setActive(true)
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
