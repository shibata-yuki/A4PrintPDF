//
//  PDFGenerator.swift
//  A4PrintPDF
//

#if canImport(UIKit)
import UIKit

enum PDFLayout {
    static let a4Width: CGFloat = 595.28
    static let a4Height: CGFloat = 841.89
    static let margin: CGFloat = 14.17 // 5mm
    static let columns = 2
    static let rows = 2

    static let cellWidth: CGFloat = (a4Width - margin * 2) / CGFloat(columns)
    static let cellHeight: CGFloat = (a4Height - margin * 2) / CGFloat(rows)

    static func cellRect(index: Int) -> CGRect {
        let col = index % columns
        let row = index / columns
        let x = margin + CGFloat(col) * cellWidth
        let y = margin + CGFloat(row) * cellHeight
        return CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
    }
}

enum PDFGenerator {
    static let maxPixelDimension: CGFloat = 3000

    static func generatePDF(from images: [UIImage]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: PDFLayout.a4Width, height: PDFLayout.a4Height)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            for (index, image) in images.prefix(4).enumerated() {
                autoreleasepool {
                    let cell = PDFLayout.cellRect(index: index)
                    let drawRect = aspectFitRect(for: image.size, in: cell)
                    image.draw(in: drawRect)
                }
            }
        }
    }

    static func shouldRotate(_ imageSize: CGSize, for cell: CGRect) -> Bool {
        let isLandscape = imageSize.width > imageSize.height
        let cellIsPortrait = cell.width < cell.height

        guard isLandscape && cellIsPortrait else { return false }

        let normalScale = min(cell.width / imageSize.width, cell.height / imageSize.height)
        let normalArea = (imageSize.width * normalScale) * (imageSize.height * normalScale)

        let rotatedW = imageSize.height
        let rotatedH = imageSize.width
        let rotatedScale = min(cell.width / rotatedW, cell.height / rotatedH)
        let rotatedArea = (rotatedW * rotatedScale) * (rotatedH * rotatedScale)

        return rotatedArea > normalArea
    }

    static func autoRotate(_ image: UIImage, for cell: CGRect) -> UIImage {
        guard shouldRotate(image.size, for: cell) else { return image }

        let newSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { ctx in
            let context = ctx.cgContext
            context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.rotate(by: .pi / 2)
            context.translateBy(x: -image.size.width / 2, y: -image.size.height / 2)
            image.draw(at: .zero)
        }
    }

    private static func aspectFitRect(for imageSize: CGSize, in cell: CGRect) -> CGRect {
        let scale = min(cell.width / imageSize.width, cell.height / imageSize.height)
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let x = cell.origin.x + (cell.width - drawWidth) / 2
        let y = cell.origin.y + (cell.height - drawHeight) / 2
        return CGRect(x: x, y: y, width: drawWidth, height: drawHeight)
    }

    static func downsampleIfNeeded(_ image: UIImage) -> UIImage {
        let maxDim = max(image.size.width * image.scale, image.size.height * image.scale)
        guard maxDim > maxPixelDimension else { return image }

        let scale = maxPixelDimension / maxDim
        let newSize = CGSize(
            width: image.size.width * image.scale * scale,
            height: image.size.height * image.scale * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif
