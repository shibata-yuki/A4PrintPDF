//
//  PDFPreviewView.swift
//  A4PrintPDF
//

#if canImport(UIKit)
import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.dataRepresentation() != data {
            pdfView.document = PDFDocument(data: data)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private class ImageSaver: NSObject {
    var onComplete: ((Bool) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        onComplete = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(handleResult), nil)
    }

    @objc private func handleResult(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        onComplete?(error == nil)
    }
}

struct PDFPreviewView: View {
    let pdfData: Data
    @State private var showingShare = false
    @State private var tempURL: URL?
    @State private var imageSaveResult: Bool?
    @State private var imageSaver: ImageSaver?

    var body: some View {
        PDFKitView(data: pdfData)
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAsImage()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sensoryFeedback(.success, trigger: imageSaveResult) { _, newValue in
                newValue == true
            }
            .overlay {
                if let result = imageSaveResult {
                    savedToast(success: result)
                }
            }
            .onChange(of: showingShare) {
                if showingShare {
                    tempURL = saveTempPDF()
                }
            }
            .sheet(isPresented: $showingShare) {
                if let tempURL {
                    ShareSheet(items: [tempURL])
                        .presentationDetents([.medium, .large])
                }
            }
    }

    private func savedToast(success: Bool) -> some View {
        Label(
            success ? "写真に保存しました" : "保存に失敗しました",
            systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(success ? .primary : .red)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .transition(.move(edge: .top).combined(with: .opacity))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }

    private func saveAsImage() {
        guard let page = PDFDocument(data: pdfData)?.page(at: 0) else { return }
        let pageRect = page.bounds(for: .mediaBox)
        // A4 at 300 DPI: 2480 x 3508 px
        let dpi: CGFloat = 300
        let pxWidth = round(pageRect.width * dpi / 72)
        let pxHeight = round(pageRect.height * dpi / 72)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: pxWidth, height: pxHeight),
            format: format
        )
        let image = renderer.image { ctx in
            let context = ctx.cgContext
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: pxWidth, height: pxHeight))
            // PDFPage の描画は左下原点なので座標変換
            context.translateBy(x: 0, y: pxHeight)
            context.scaleBy(x: dpi / 72, y: -(dpi / 72))
            page.draw(with: .mediaBox, to: context)
        }

        let saver = ImageSaver()
        saver.save(image) { success in
            withAnimation {
                imageSaveResult = success
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    imageSaveResult = nil
                }
            }
        }
        imageSaver = saver
    }

    private func saveTempPDF() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("A4PrintPDF_\(formattedDate()).pdf")
        try? pdfData.write(to: url)
        return url
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
#endif
