import Foundation

enum FeslihanError: LocalizedError {
    case videoLoadFailed
    case audioExtractionFailed
    case recipeParseFailed
    case captionFetchFailed
    case noInputProvided
    case notARecipe

    var errorDescription: String? {
        switch self {
        case .videoLoadFailed:
            return "Video yüklenemedi"
        case .audioExtractionFailed:
            return "Ses ayıklanamadı"
        case .recipeParseFailed:
            return "Tarif işlenemedi"
        case .captionFetchFailed:
            return "Video açıklaması alınamadı"
        case .noInputProvided:
            return "Bir URL veya video seçmelisiniz"
        case .notARecipe:
            return "Bu içerik bir yemek tarifi değil. Lütfen bir tarif videosu linki girin."
        }
    }
}
