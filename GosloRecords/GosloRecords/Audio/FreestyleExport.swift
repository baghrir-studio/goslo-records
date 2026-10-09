import AVFoundation
import CoreGraphics
import CoreVideo

/// « Partager mon freestyle » : the beat and the voice take mixed offline into one file, then (when a picture is
/// given) a short video of that still picture over the mix, since Instagram and TikTok take videos, not sounds.
/// Everything is written to the temporary directory; nothing leaves the phone until the player shares it.
enum FreestyleExport {
    enum Failure: Error { case missingTrack, export, writer }

    /// Same balance as the booth's playback: the beat a bit under the voice.
    private static let beatVolume: Float = 0.75

    // MARK: Audio

    /// Mixes the beat (from its start) and the voice (minus `voiceOffset`, the round trip the sound made through
    /// the speaker and the microphone) into an AAC .m4a file.
    static func mixAudio(beat: URL, voice: URL, voiceOffset: TimeInterval, to output: URL) async throws {
        let beatAsset = AVURLAsset(url: beat)
        let voiceAsset = AVURLAsset(url: voice)
        let composition = AVMutableComposition()
        guard let beatSource = try await beatAsset.loadTracks(withMediaType: .audio).first,
              let voiceSource = try await voiceAsset.loadTracks(withMediaType: .audio).first,
              let beatTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let voiceTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Failure.missingTrack }
        let beatDuration = try await beatAsset.load(.duration)
        let voiceDuration = try await voiceAsset.load(.duration)

        try beatTrack.insertTimeRange(CMTimeRange(start: .zero, duration: beatDuration), of: beatSource, at: .zero)
        let offset = CMTime(seconds: max(0, voiceOffset), preferredTimescale: 44_100)
        if voiceDuration.seconds > offset.seconds + 0.05 {
            try voiceTrack.insertTimeRange(CMTimeRange(start: offset, end: voiceDuration), of: voiceSource, at: .zero)
        }

        let beatLevel = AVMutableAudioMixInputParameters(track: beatTrack)
        beatLevel.setVolume(beatVolume, at: .zero)
        let voiceLevel = AVMutableAudioMixInputParameters(track: voiceTrack)
        voiceLevel.setVolume(1, at: .zero)
        let mix = AVMutableAudioMix()
        mix.inputParameters = [beatLevel, voiceLevel]

        try await export(composition, preset: AVAssetExportPresetAppleM4A, fileType: .m4a, audioMix: mix, to: output)
    }

    // MARK: Video

    /// A vertical .mp4: `image` held still for the whole mix, with the mix as its sound.
    static func video(image: CGImage, audio: URL, to output: URL) async throws {
        let audioAsset = AVURLAsset(url: audio)
        let duration = try await audioAsset.load(.duration)
        let still = FileManager.default.temporaryDirectory.appendingPathComponent("freestyle-image-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: still) }
        try await writeStill(image, seconds: duration.seconds, to: still)

        let videoAsset = AVURLAsset(url: still)
        let composition = AVMutableComposition()
        guard let videoSource = try await videoAsset.loadTracks(withMediaType: .video).first,
              let audioSource = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Failure.missingTrack }
        let videoDuration = try await videoAsset.load(.duration)
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(videoDuration, duration)),
                                       of: videoSource, at: .zero)
        try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioSource, at: .zero)

        try await export(composition, preset: AVAssetExportPresetHighestQuality, fileType: .mp4, audioMix: nil, to: output)
    }

    /// A silent H.264 video of one picture: the same frame a few times a second, so every player shows it.
    private static func writeStill(_ image: CGImage, seconds: Double, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        // H.264 wants even sizes.
        let width = max(2, image.width & ~1)
        let height = max(2, image.height & ~1)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw Failure.writer }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Failure.writer }
        writer.startSession(atSourceTime: .zero)

        let frame = try pixelBuffer(of: image, width: width, height: height)
        let fps: Int32 = 5
        let frames = max(2, Int((max(seconds, 0.5) * Double(fps)).rounded(.up)) + 1)
        for index in 0..<frames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            let time = CMTime(value: CMTimeValue(index), timescale: fps)
            guard adaptor.append(frame, withPresentationTime: time) else {
                writer.cancelWriting()
                throw writer.error ?? Failure.writer
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? Failure.writer }
    }

    private static func pixelBuffer(of image: CGImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attributes, &buffer)
        guard status == kCVReturnSuccess, let buffer else { throw Failure.writer }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        else { throw Failure.writer }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    // MARK: Export

    private static func export(_ asset: AVAsset, preset: String, fileType: AVFileType, audioMix: AVAudioMix?,
                               to output: URL) async throws {
        try? FileManager.default.removeItem(at: output)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { throw Failure.export }
        session.outputURL = output
        session.outputFileType = fileType
        session.audioMix = audioMix
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        guard session.status == .completed else { throw session.error ?? Failure.export }
    }
}
