import AVFoundation
import Foundation

/// Small original paper and printer sounds. They are mixed with other audio and
/// follow the review editor's existing sound preference.
@MainActor
final class ReviewReceiptSound {
    enum Event: Int {
        case printerTick
        case perforation
        case separation
    }

    private var players: [Event: [AVAudioPlayer]] = [:]
    private var lastPlayedAt: [Event: CFAbsoluteTime] = [:]

    func play(_ event: Event, intensity: Float, enabled: Bool) {
        guard enabled else { return }
        let now = CFAbsoluteTimeGetCurrent()
        if now - (lastPlayedAt[event] ?? 0) < 0.045 { return }
        lastPlayedAt[event] = now
        if players[event] == nil {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            players[event] = (0..<3).compactMap { variant in
                try? AVAudioPlayer(data: Self.wave(for: event, variant: variant))
            }
            players[event]?.forEach { $0.prepareToPlay() }
        }
        guard let pool = players[event],
              let player = pool.first(where: { !$0.isPlaying }) ?? pool.first else { return }
        player.currentTime = 0
        player.volume = min(0.22, max(0, intensity))
        player.play()
    }

    private static func wave(for event: Event, variant: Int) -> Data {
        let sampleRate = 22_050
        let duration: Double
        switch event {
        case .printerTick: duration = 0.075
        case .perforation: duration = 0.42
        case .separation: duration = 0.30
        }
        let count = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: count * 2)
        var seed = UInt32(19_273 + event.rawValue * 7_919 + variant * 17_003)
        var smoothedNoise = 0.0
        for index in 0..<count {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Double(seed) / Double(UInt32.max) * 2 - 1
            let time = Double(index) / Double(sampleRate)
            let sample: Double
            switch event {
            case .printerTick:
                sample = noise * exp(-time * 95) * 0.62
                    + sin(time * 1_180 * 2 * .pi) * exp(-time * 68) * 0.24
            case .perforation:
                // Broadband, irregular crackle gives the rip a papery texture.
                // The uneven envelope avoids the descending electronic chirp.
                smoothedNoise = smoothedNoise * 0.42 + noise * 0.58
                let grain = noise * 0.72 + (noise - smoothedNoise) * 0.55
                let flutter = 0.26 + 0.74 * abs(sin(2 * .pi * (31 * time + 63 * time * time)))
                sample = grain * exp(-time * 2.4) * flutter * 0.58
            case .separation:
                smoothedNoise = smoothedNoise * 0.5 + noise * 0.5
                let flap = time < 0.07 ? 0.9 : (time < 0.2 ? 0.35 : exp(-(time - 0.2) * 24))
                sample = (noise * 0.68 + (noise - smoothedNoise) * 0.46) * flap * 0.52
            }
            var value = Int16(max(-1, min(1, sample)) * 23_000).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        var wave = Data()
        func ascii(_ value: String) { wave.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { wave.append(contentsOf: $0) }
        }
        func u32(_ value: UInt32) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { wave.append(contentsOf: $0) }
        }
        ascii("RIFF")
        u32(UInt32(pcm.count + 36))
        ascii("WAVEfmt ")
        u32(16)
        u16(1)
        u16(1)
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))
        u16(2)
        u16(16)
        ascii("data")
        u32(UInt32(pcm.count))
        wave.append(pcm)
        return wave
    }
}
