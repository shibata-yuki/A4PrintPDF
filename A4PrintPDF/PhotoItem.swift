//
//  PhotoItem.swift
//  A4PrintPDF
//

#if canImport(UIKit)
import UIKit

struct PhotoItem: Identifiable {
    let id = UUID()
    let originalImage: UIImage
    var displayImage: UIImage
    var cropRect: CGRect?  // 正規化された切り抜き範囲（0...1）、nil=全体
}
#endif
