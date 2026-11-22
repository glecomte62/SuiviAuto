import AppKit
import PDFKit
import UniformTypeIdentifiers
import Vision

/// Lit le texte d'une facture ou d'un devis (PDF ou image), sur le Mac et hors ligne, puis l'analyse.
enum InvoiceOCRService {
    enum OCRError: LocalizedError {
        case unreadable
        var errorDescription: String? { "Ce document ne peut pas être lu." }
    }

    static let maxPages = 3
    /// En dessous de ce nombre moyen de caractères par page, la couche texte d'un PDF est un simple filigrane
    /// (« Numérisé avec CamScanner »…) : on lit l'image.
    static let minTextLayerCharsPerPage = 20
    private static let maxRenderSide: CGFloat = 4000

    /// Lève `CancellationError` si l'appelant est annulé (même quand la lecture a fini entre-temps),
    /// et `OCRError.unreadable` (ou l'erreur de Vision) si le fichier ne peut pas être lu.
    static func analyze(fileAt url: URL, calendar: Calendar = .current) async throws -> InvoiceExtraction {
        try Task.checkCancellation()
        let task = Task.detached(priority: .userInitiated) { try extract(at: url, calendar: calendar) }
        let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        try Task.checkCancellation()
        return result
    }

    private static func extract(at url: URL, calendar: Calendar) throws -> InvoiceExtraction {
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true {
            guard let doc = PDFDocument(url: url) else { throw OCRError.unreadable }
            let pages = (0..<min(doc.pageCount, maxPages)).compactMap { doc.page(at: $0) }
            let layer = pages.map(textLayer).joined(separator: "\n")
            let layerResult = InvoiceTextParser.parse(layer, calendar: calendar)
            let chars = layer.filter { !$0.isWhitespace }.count
            if !layerResult.isEmpty, chars >= minTextLayerCharsPerPage * max(pages.count, 1) { return layerResult }
            var parts: [String] = []
            for page in pages {
                try Task.checkCancellation()
                let text: String? = autoreleasepool {
                    guard let image = render(page) else { return nil }
                    return try? recognize(image, orientation: .up)
                }
                if let text { parts.append(text) }
            }
            let ocrResult = InvoiceTextParser.parse(parts.joined(separator: "\n"), calendar: calendar)
            return ocrResult.isEmpty ? layerResult : ocrResult
        }
        guard type?.conforms(to: .image) == true,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw OCRError.unreadable }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? UInt32).flatMap(CGImagePropertyOrientation.init) ?? .up
        try Task.checkCancellation()
        return InvoiceTextParser.parse(try recognize(image, orientation: orientation), calendar: calendar)
    }

    /// Couche texte d'une page, remise en lignes (les PDF de garage sont souvent écrits colonne par colonne).
    private static func textLayer(_ page: PDFPage) -> String {
        let lines = page.selection(for: page.bounds(for: .cropBox))?.selectionsByLine() ?? []
        let fragments = lines.compactMap { line -> (text: String, rect: CGRect)? in
            guard let s = line.string else { return nil }
            return (s, line.bounds(for: page))
        }
        return TextLayout.rows(fragments, yAxisUp: true)
    }

    /// Image de la page telle qu'affichée (boîte de recadrage, rotation appliquée), plus grand côté ≤ 4000 px.
    private static func render(_ page: PDFPage, scale: CGFloat = 2.5) -> CGImage? {
        let bounds = page.bounds(for: .cropBox)
        var size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        if page.rotation % 180 != 0 { size = CGSize(width: size.height, height: size.width) }
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let k = min(1, maxRenderSide / longest)
        size = CGSize(width: (size.width * k).rounded(), height: (size.height * k).rounded())
        return page.thumbnail(of: size, for: .cropBox).cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
        let fragments = (request.results ?? []).compactMap { obs -> (text: String, rect: CGRect)? in
            guard let s = obs.topCandidates(1).first?.string else { return nil }
            return (s, obs.boundingBox)
        }
        return TextLayout.rows(fragments, yAxisUp: true)
    }
}
