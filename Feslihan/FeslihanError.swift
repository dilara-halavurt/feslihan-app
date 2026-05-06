import Foundation

enum FeslihanError: LocalizedError {
    case videoLoadFailed
    case audioExtractionFailed
    case transcriptionFailed
    case recipeParseFailed
    case apiKeyMissing(String)
    case captionFetchFailed
    case noInputProvided
    case notARecipe

    var errorDescription: String? {
        switch self {
        case .videoLoadFailed:
            return "Video yüklenemedi"
        case .audioExtractionFailed:
            return "Ses ayıklanamadı"
        case .transcriptionFailed:
            return "Yazıya çevirme başarısız oldu"
        case .recipeParseFailed:
            return "Tarif işlenemedi"
        case .apiKeyMissing(let service):
            return "\(service) API anahtarı gerekli. Ayarlar'dan ekleyin."
        case .captionFetchFailed:
            return "Video açıklaması alınamadı"
        case .noInputProvided:
            return "Bir URL veya video seçmelisiniz"
        case .notARecipe:
            return "Bu içerik bir yemek tarifi değil. Lütfen bir tarif videosu linki girin."
        }
    }
}
