import XCTest
@testable import GosloRecords

/// The music and effects are generated in code: check they render cleanly.
final class SoundTests: XCTestCase {
    func testTracksLoopForWholeBars() {
        for track in SoundTrack.allCases {
            let samples = track.render()
            let groove = track.groove
            let expected = Synth.count(groove.stepSeconds * 16 * Double(groove.bars))
            XCTAssertEqual(samples.count, expected, "\(track) ne boucle pas sur des mesures entières")
            assertClean(samples, track.rawValue)
            XCTAssertGreaterThan(rms(samples), 0.05, "\(track) est quasi muet")
        }
    }

    func testEffectsAreShortAndClean() {
        for effect in SoundEffect.allCases {
            let samples = effect.render()
            assertClean(samples, effect.rawValue)
            XCTAssertLessThan(Double(samples.count) / Synth.sampleRate, 3, "\(effect) est trop long")
            XCTAssertGreaterThan(effect.volume, 0)
        }
    }

    func testConcertSongsRenderWholeAndClean() {
        let song = ConcertSong(title: "t", bpm: 96, bars: 6, density: 0.5)
        for index in 0..<4 {
            let samples = ConcertMix.render(song, seed: ConcertEngine.seed("premier_concert", song: index))
            XCTAssertEqual(samples.count, Synth.count(song.duration), "le morceau dure exactement le temps des notes")
            assertClean(samples, "concert \(index)")
            XCTAssertGreaterThan(rms(samples), 0.05, "concert \(index) quasi muet")
        }
    }

    func testRenderingIsDeterministic() {
        XCTAssertEqual(SoundEffect.hit.render(), SoundEffect.hit.render())
        XCTAssertEqual(SoundTrack.drill.render(), SoundTrack.drill.render())
    }

    func testSwingOnlyMovesOffBeats() {
        let seq = Sequencer(bpm: 90, bars: 1, swing: 0.2)
        XCTAssertEqual(seq.offset(of: 2), Int(2 * seq.stepSeconds * Synth.sampleRate))
        XCTAssertGreaterThan(seq.offset(of: 3), Int(3 * seq.stepSeconds * Synth.sampleRate))
    }

    func testWrappedTailsLoopBack() {
        var buffer = [Float](repeating: 0, count: 10)
        Synth.add([1, 1, 1, 1], into: &buffer, at: 8, gain: 1, wrap: true)
        XCTAssertEqual(buffer, [1, 1, 0, 0, 0, 0, 0, 0, 1, 1])
    }

    private func assertClean(_ samples: [Float], _ name: String) {
        XCTAssertFalse(samples.isEmpty, name)
        XCTAssertTrue(samples.allSatisfy(\.isFinite), "\(name) contient des valeurs invalides")
        XCTAssertLessThanOrEqual(samples.reduce(0) { max($0, abs($1)) }, 0.86, "\(name) sature")
    }

    private func rms(_ samples: [Float]) -> Float {
        sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}
