//
//  ImageFilters.swift
//  A4PrintPDF
//

#if canImport(UIKit)
import UIKit
import CoreImage

enum ImageFilters {
    private static let ciContext = CIContext()

    static func applyMonochrome(to image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CIPhotoEffectMono") else { return image }

        filter.setValue(ciImage, forKey: kCIInputImageKey)

        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else { return image }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
#endif
