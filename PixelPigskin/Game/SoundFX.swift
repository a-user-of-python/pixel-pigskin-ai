import AVFoundation

/// Chiptune-style SFX: tiny square/triangle-wave synth, zero audio files.
/// Everything is generated in code with AVAudioEngine.
final class SoundFX {
    static let shared = SoundFX()

    enum Sound {
        case snap, throwBall, catchBall, tackle, whistle, kick, cheer,
             buzzer, click, touchdown, interception, firstDown
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        try? engine.start()
    }

    func play(_ s: Sound) {
        let seq: [(freq: Float, dur: Float, wave: Wave)]
        switch s {
        case .snap:        seq = [(220, 0.06, .square)]
        case .throwBall:    seq = [(330, 0.05, .square), (440, 0.05, .square)]
        case .catchBall:    seq = [(660, 0.07, .square)]
        case .tackle:       seq = [(110, 0.12, .noise), (82, 0.1, .square)]
        case .whistle:      seq = [(2093, 0.25, .square), (2093, 0.15, .square)]
        case .kick:         seq = [(150, 0.12, .triangle)]
        case .cheer:        seq = [(523, 0.09, .square), (659, 0.09, .square),
                                   (784, 0.09, .square), (1046, 0.25, .square)]
        case .buzzer:       seq = [(140, 0.5, .square)]
        case .click:        seq = [(880, 0.04, .square)]
        case .touchdown:    seq = [(523, 0.1, .square), (659, 0.1, .square),
                                   (784, 0.1, .square), (1046, 0.3, .square),
                                   (784, 0.15, .square), (1046, 0.4, .square)]
        case .interception: seq = [(392, 0.12, .square), (311, 0.12, .square),
                                   (233, 0.25, .square)]
        case .firstDown:    seq = [(587, 0.08, .square), (880, 0.12, .square)]
        }
        for (freq, dur, wave) in seq {
            let buf = makeTone(freq: freq, dur: dur, wave: wave)
            player.scheduleBuffer(buf, options: [])
        }
        if !player.isPlaying { player.play() }
    }

    private enum Wave { case square, triangle, noise }

    private func makeTone(freq: Float, dur: Float, wave: Wave) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(sampleRate * Double(dur))
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let ch = buf.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Float(i) / Float(sampleRate)
            let phase = 2 * Float.pi * freq * t
            let s: Float
            switch wave {
            case .square:   s = sin(phase) >= 0 ? 0.5 : -0.5
            case .triangle: s = asin(sin(phase)) * 0.4
            case .noise:    s = Float.random(in: -0.5...0.5)
            }
            // Simple decay envelope so it sounds chiptune, not harsh.
            let env = 1 - Float(i) / Float(frames)
            ch[i] = s * env * 0.35
        }
        return buf
    }
}
