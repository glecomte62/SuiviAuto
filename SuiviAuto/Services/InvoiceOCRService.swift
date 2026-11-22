import AppKit
import PDFKit
import Vision

/// Lit le texte d'une facture ou d'un devis (PDF ou image), sur le Mac et hors ligne, puis l'analyse.
enum InvoiceOCRService {
    enum OCRError: LocalizedError {
        case unreadable
        var errorDescription: String? { "Ce document ne peut pas être lu." }
    }

    static let maxPages = 3

    static func analyze(fileAt url: URL, calendar: Calendar = .current) async throws -> InvoiceExtraction {
        let text = try await Task.detached(priority: .userInitiated) { try recognizeText(at: url) }.value
        return InvoiceTextParser.parse(text, calendar: calendar)
    }

    static func recognizeText(at url: URL) throws -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let doc = PDFDocument(url: url) else { throw OCRError.unreadable }
            if let layer = doc.string, layer.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 {
                return layer
            }
            var parts: [String] = []
            for index in 0..<min(doc.pageCount, maxPages) {
                guard let page = doc.page(at: index), let image = render(page) else { continue }
                parts.append(try recognize(image))
            }
            return parts.joined(separator: "\n")
        case "jpg", "jpeg", "png", "heic":
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw OCRError.unreadable }
            return try recognize(image)
        default:
            throw OCRError.unreadable
        }
    }

    private static func render(_ page: PDFPage, scale: CGFloat = 2.5) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
        guard width > 0, height > 0,
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }

    private static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
