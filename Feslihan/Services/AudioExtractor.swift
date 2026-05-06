import AVFoundation
import Foundation

enum AudioExtractor {
    static func extractAudio(from videoURL: URL) async throws -> URL {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")

        let asset = AVURLAsset(url: videoURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw FeslihanError.audioExtractionFailed
        }

        exportSession.outputURL = audioURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw FeslihanError.audioExtractionFailed
        }

        return audioURL
    }
}
