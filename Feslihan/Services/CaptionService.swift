import Foundation

struct CaptionResult {
    let caption: String
    let thumbnailData: Data?
    var authorName: String?
}

enum CaptionService {
    static func fetchCaption(from urlString: String) async throws -> CaptionResult {
        let trimmed = cleanURL(urlString.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let url = URL(string: trimmed) else {
            throw FeslihanError.captionFetchFailed
        }
        let host = url.host?.lowercased() ?? ""

        // For TikTok/X: try oEmbed first (works with shortened URLs, returns real caption)
        let encodedURL = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed

        let oEmbedEndpoint: String? = if host.contains("tiktok") || host.contains("vt.tiktok") {
            "https://www.tiktok.com/oembed?url=\(encodedURL)"
        } else if host.contains("twitter") || host.contains("x.com") {
            "https://publish.twitter.com/oembed?url=\(encodedURL)"
        } else {
            nil
        }

        if let endpoint = oEmbedEndpoint, let oEmbedURL = URL(string: endpoint) {
            var request = URLRequest(url: oEmbedURL)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = json["title"] as? String, !title.isEmpty,
               !isGenericCaption(title) {
                let thumbURL = json["thumbnail_url"] as? String
                let thumbData = await downloadImage(from: thumbURL)
                let author = json["author_unique_id"] as? String
                    ?? json["author_name"] as? String
                return CaptionResult(caption: title, thumbnailData: thumbData, authorName: author)
            }
        }

        // Fallback: try OG tags from HTML
        if let result = try? await fetchFromHTML(urlString: trimmed),
           !isGenericCaption(result.caption) {
            return result
        }

        throw FeslihanError.captionFetchFailed
    }

    static func downloadImage(from urlString: String?) async -> Data? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        return data
    }

    /// Strip tracking params (igsh, utm_, etc.) that cause Instagram to return sharing text
    private static func cleanURL(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        let blocked = ["igsh", "igshid", "ig_mid"]
        components.queryItems = components.queryItems?.filter { item in
            !blocked.contains(item.name) && !item.name.hasPrefix("utm_")
        }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }
        return components.url?.absoluteString ?? urlString
    }

    /// Detect generic Instagram sharing captions that aren't real content
    private static func isGenericCaption(_ caption: String) -> Bool {
        let lower = caption.lowercased()
        let patterns = [
            "shared a post",
            "shared a reel",
            "shared this video",
            "shared an instagram",
            "has shared",
            "shared a video with you",
            "watch this video on tiktok",
            "watch on the app",
            "join me on tiktok",
            "paylaştı",
            "bu videoyu paylaştı",
        ]
        return patterns.contains { lower.contains($0) }
    }

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private static func fetchFromHTML(urlString: String) async throws -> CaptionResult {
        guard let url = URL(string: urlString) else {
            throw FeslihanError.captionFetchFailed
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let html = decodeResponseData(data, response: response)
        guard !html.isEmpty else {
            throw FeslihanError.captionFetchFailed
        }

        // Extract thumbnail from og:image
        let rawImageURL = extractMetaContent(from: html, attr: "property", value: "og:image")
            ?? extractMetaContent(from: html, attr: "name", value: "twitter:image")
        let imageURL = rawImageURL?
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        // Try multiple meta tag formats used by social platforms
        let properties = ["og:description", "twitter:description", "description"]
        for prop in properties {
            if let content = extractMetaContent(from: html, attr: "property", value: prop)
                ?? extractMetaContent(from: html, attr: "name", value: prop) {
                let decoded = decodeHTMLEntities(content)
                if !decoded.isEmpty, !isGenericCaption(decoded) {
                    let thumbData = await downloadImage(from: imageURL)
                    return CaptionResult(caption: decoded, thumbnailData: thumbData)
                }
            }
        }

        // Try to find JSON-LD structured data (Instagram uses this)
        if let jsonLD = extractJSONLD(from: html) {
            let thumbData = await downloadImage(from: imageURL)
            return CaptionResult(caption: jsonLD, thumbnailData: thumbData)
        }

        throw FeslihanError.captionFetchFailed
    }

    private static func extractMetaContent(from html: String, attr: String, value: String) -> String? {
        // Match: <meta property="og:description" content="...">
        // Also:  <meta content="..." property="og:description">
        // Handle single and double quotes, and optional spaces
        let patterns = [
            "<meta[^>]+\(attr)=[\"']\(value)[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+\(attr)=[\"']\(value)[\"']"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }

    // MARK: - Encoding

    private static func decodeResponseData(_ data: Data, response: URLResponse?) -> String {
        // Try to detect encoding from HTTP headers
        if let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
            // Check for charset in Content-Type header
            if contentType.contains("iso-8859-9") || contentType.contains("windows-1254") {
                // Turkish encoding
                let cfEncoding = CFStringConvertIANACharSetNameToEncoding("iso-8859-9" as CFString)
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                if let str = String(data: data, encoding: String.Encoding(rawValue: nsEncoding)) {
                    return str
                }
            }
            if contentType.contains("iso-8859-1") || contentType.contains("latin1") {
                if let str = String(data: data, encoding: .isoLatin1) {
                    return str
                }
            }
        }

        // Try UTF-8 first, then common fallbacks
        if let str = String(data: data, encoding: .utf8) { return str }
        // Turkish ISO-8859-9
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding("iso-8859-9" as CFString)
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        if let str = String(data: data, encoding: String.Encoding(rawValue: nsEncoding)) { return str }
        if let str = String(data: data, encoding: .isoLatin1) { return str }
        return String(data: data, encoding: .ascii) ?? ""
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        // Use NSAttributedString for robust HTML entity decoding (handles all entities)
        let wrapped = "<meta charset=\"UTF-8\">\(string)"
        if let data = wrapped.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ) {
            return attributed.string
        }

        // Manual fallback for numeric HTML entities
        var result = string
        result = result.replacingOccurrences(of: "\\n", with: "\n")

        // Decode &#NNN; (decimal)
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let mutable = NSMutableString(string: result)
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[codeRange]),
                   let scalar = Unicode.Scalar(code) {
                    let char = String(Character(scalar))
                    mutable.replaceCharacters(in: match.range, with: char)
                }
            }
            result = mutable as String
        }

        // Decode &#xHHH; (hex)
        if let regex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);") {
            let mutable = NSMutableString(string: result)
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[codeRange], radix: 16),
                   let scalar = Unicode.Scalar(code) {
                    let char = String(Character(scalar))
                    mutable.replaceCharacters(in: match.range, with: char)
                }
            }
            result = mutable as String
        }

        // Common named entities
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&apos;": "'", "&#39;": "'",
            "&nbsp;": " ", "&ndash;": "–", "&mdash;": "—",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}",
            "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        return result
    }

    private static func extractJSONLD(from html: String) -> String? {
        // Look for <script type="application/ld+json">...</script>
        let pattern = "<script[^>]+type=[\"']application/ld\\+json[\"'][^>]*>([\\s\\S]*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[range])
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Check for description/caption in common fields
            if let desc = json["description"] as? String, !desc.isEmpty {
                return decodeHTMLEntities(desc)
            }
            if let desc = json["caption"] as? String, !desc.isEmpty {
                return decodeHTMLEntities(desc)
            }
            if let desc = json["articleBody"] as? String, !desc.isEmpty {
                return decodeHTMLEntities(desc)
            }
        }

        return nil
    }
}
