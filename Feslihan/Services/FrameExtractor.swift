import AVFoundation
import UIKit

enum FrameExtractor {
    static func extractFrames(from videoURL: URL, framesPerSecond: Double = 1) async throws -> [Data] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 720)

        let maxFrames = 100 // Claude API limit per request
        let rawCount = max(1, Int(durationSeconds * framesPerSecond))
        let frameCount = min(rawCount, maxFrames)
        let interval = durationSeconds / Double(frameCount + 1)
        let times = (1...frameCount).map { i in
            CMTime(seconds: interval * Double(i), preferredTimescale: 600)
        }

        var frames: [Data] = []
        for time in times {
            do {
                let (cgImage, _) = try await generator.image(at: time)
                let uiImage = UIImage(cgImage: cgImage)
                if let jpegData = uiImage.jpegData(compressionQuality: 0.6) {
                    frames.append(jpegData)
                }
            } catch {
                continue
            }
        }

        return frames
    }
}
