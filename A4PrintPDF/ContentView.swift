//
//  ContentView.swift
//  A4PrintPDF
//

#if canImport(UIKit)
import SwiftUI
import PhotosUI

private struct CropTarget: Identifiable {
    let id = UUID()
    let index: Int
    let item: PhotoItem
}

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoItems: [PhotoItem] = []
    @State private var isMonochrome = false
    @State private var pdfData: Data?
    @State private var isGenerating = false
    @State private var showPreview = false
    @State private var tappedIndex: Int?
    @State private var showCellMenu = false
    @State private var replacingIndex: Int?
    @State private var showReplacementPicker = false
    @State private var replacementItem: PhotosPickerItem?
    @State private var croppingIndex: Int?
    @State private var showAddPicker = false
    @State private var addPickerItem: PhotosPickerItem?
    @State private var dropTargetIndex: Int?
    @State private var adManager = AdInterstitialManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                photoGrid
                    .padding(.horizontal)

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 4,
                    matching: .images
                ) {
                    Label(
                        photoItems.isEmpty ? "写真を選択（最大4枚）" : "写真を変更",
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .font(.headline)
                }

                if !photoItems.isEmpty {
                    Toggle("白黒モード", isOn: $isMonochrome)
                        .padding(.horizontal)

                    Button {
                        generatePDF()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text("A4データを作成")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("写真4枚→A4")
            .sensoryFeedback(.success, trigger: pdfData) { oldValue, newValue in
                newValue != nil
            }
            .navigationDestination(isPresented: $showPreview) {
                if let pdfData {
                    PDFPreviewView(pdfData: pdfData)
                }
            }
            .onAppear {
                adManager.loadAd()
            }
            .onChange(of: selectedItems) {
                loadImages()
            }
            .onChange(of: isMonochrome) {
                reprocessImages()
            }
            .confirmationDialog("写真の編集", isPresented: $showCellMenu, presenting: tappedIndex) { index in
                Button("差し替え") {
                    replacingIndex = index
                    showReplacementPicker = true
                }
                Button("トリミング") {
                    croppingIndex = index
                }
                Button("削除", role: .destructive) {
                    photoItems.remove(at: index)
                }
                Button("キャンセル", role: .cancel) {}
            }
            .photosPicker(isPresented: $showReplacementPicker, selection: $replacementItem, matching: .images)
            .onChange(of: replacementItem) {
                guard let item = replacementItem, let index = replacingIndex else { return }
                replacementItem = nil
                let targetIndex = index
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        let processed = processImage(image, cropRect: nil)
                        if targetIndex < photoItems.count {
                            photoItems[targetIndex] = PhotoItem(originalImage: image, displayImage: processed, cropRect: nil)
                        }
                    }
                    replacingIndex = nil
                }
            }
            .photosPicker(isPresented: $showAddPicker, selection: $addPickerItem, matching: .images)
            .onChange(of: addPickerItem) {
                guard let item = addPickerItem else { return }
                addPickerItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       photoItems.count < 4 {
                        let processed = processImage(image, cropRect: nil)
                        photoItems.append(PhotoItem(originalImage: image, displayImage: processed, cropRect: nil))
                    }
                }
            }
            .fullScreenCover(item: Binding(
                get: {
                    if let idx = croppingIndex, idx < photoItems.count {
                        return CropTarget(index: idx, item: photoItems[idx])
                    }
                    return nil
                },
                set: { _ in croppingIndex = nil }
            )) { target in
                CropView(
                    image: target.item.originalImage,
                    initialCropRect: target.item.cropRect,
                    onApply: { rect in
                        if target.index < photoItems.count {
                            photoItems[target.index].cropRect = rect
                            photoItems[target.index].displayImage = processImage(
                                photoItems[target.index].originalImage,
                                cropRect: rect
                            )
                        }
                        croppingIndex = nil
                    },
                    onCancel: {
                        croppingIndex = nil
                    }
                )
            }
        }
    }

    private var photoGrid: some View {
        let a4Ratio = PDFLayout.a4Height / PDFLayout.a4Width

        return GeometryReader { geo in
            let width = geo.size.width
            let height = width * a4Ratio
            let cellW = (width - PDFLayout.margin * 2 * width / PDFLayout.a4Width) / 2
            let cellH = (height - PDFLayout.margin * 2 * height / PDFLayout.a4Height) / 2
            let marginX = PDFLayout.margin * width / PDFLayout.a4Width
            let marginY = PDFLayout.margin * height / PDFLayout.a4Height

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: width, height: height)

                ForEach(0..<4, id: \.self) { index in
                    let col = index % 2
                    let row = index / 2
                    let x = marginX + CGFloat(col) * cellW
                    let y = marginY + CGFloat(row) * cellH

                    photoCellView(index: index, cellW: cellW, cellH: cellH)
                        .offset(x: x, y: y)
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(1 / a4Ratio, contentMode: .fit)
    }

    @ViewBuilder
    private func photoCellView(index: Int, cellW: CGFloat, cellH: CGFloat) -> some View {
        if index < photoItems.count {
            filledCellView(index: index, cellW: cellW, cellH: cellH)
        } else {
            emptyCellView(index: index, cellW: cellW, cellH: cellH)
        }
    }

    private func filledCellView(index: Int, cellW: CGFloat, cellH: CGFloat) -> some View {
        let item = photoItems[index]
        return Image(uiImage: item.displayImage)
            .resizable()
            .scaledToFit()
            .frame(width: cellW, height: cellH)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                tappedIndex = index
                showCellMenu = true
            }
            .accessibilityLabel("写真 \(index + 1)")
            .accessibilityHint("タップして編集メニューを表示")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "前に移動") {
                guard index > 0 else { return }
                withAnimation { photoItems.swapAt(index, index - 1) }
            }
            .accessibilityAction(named: "後ろに移動") {
                guard index < photoItems.count - 1 else { return }
                withAnimation { photoItems.swapAt(index, index + 1) }
            }
            .draggable(item.id.uuidString) {
                Image(uiImage: item.displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: cellW * 0.8, height: cellH * 0.8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(0.8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .opacity(dropTargetIndex == index ? 1 : 0)
            )
            .dropDestination(for: String.self) { droppedItems, _ in
                guard let sourceIDString = droppedItems.first,
                      let sourceIndex = photoItems.firstIndex(where: { $0.id.uuidString == sourceIDString }),
                      sourceIndex != index,
                      index < photoItems.count else { return false }
                withAnimation {
                    photoItems.move(
                        fromOffsets: IndexSet(integer: sourceIndex),
                        toOffset: index > sourceIndex ? index + 1 : index
                    )
                }
                return true
            } isTargeted: { isTargeted in
                dropTargetIndex = isTargeted ? index : nil
            }
    }

    private func emptyCellView(index: Int, cellW: CGFloat, cellH: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(.secondary)
            Image(systemName: "plus")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(width: cellW, height: cellH)
        .contentShape(Rectangle())
        .onTapGesture {
            if photoItems.count < 4 {
                showAddPicker = true
            }
        }
        .accessibilityLabel("空のスロット \(index + 1)")
        .accessibilityHint("タップして写真を追加")
        .accessibilityAddTraits(.isButton)
    }

    private func loadImages() {
        let items = selectedItems

        Task {
            var loaded: [PhotoItem] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let processed = processImage(image, cropRect: nil)
                    loaded.append(PhotoItem(originalImage: image, displayImage: processed, cropRect: nil))
                }
            }
            photoItems = loaded
        }
    }

    private func processImage(_ original: UIImage, cropRect: CGRect?) -> UIImage {
        var image = original

        // トリミング（UIImage.draw で orientation を正しく反映）
        if let crop = cropRect {
            let orientedSize = original.size // orientation 適用済みのサイズ
            let pixelRect = CGRect(
                x: crop.origin.x * orientedSize.width,
                y: crop.origin.y * orientedSize.height,
                width: crop.width * orientedSize.width,
                height: crop.height * orientedSize.height
            )
            if pixelRect.width > 0, pixelRect.height > 0 {
                let format = UIGraphicsImageRendererFormat()
                format.scale = original.scale
                let renderer = UIGraphicsImageRenderer(size: pixelRect.size, format: format)
                image = renderer.image { _ in
                    original.draw(at: CGPoint(x: -pixelRect.origin.x, y: -pixelRect.origin.y))
                }
            }
        }

        // ダウンサンプル
        image = PDFGenerator.downsampleIfNeeded(image)

        // 横長写真の回転
        let cell = PDFLayout.cellRect(index: 0) // 代表セルでチェック
        image = PDFGenerator.autoRotate(image, for: cell)

        // モノクロ
        if isMonochrome {
            image = ImageFilters.applyMonochrome(to: image)
        }

        return image
    }

    private func reprocessImages() {
        photoItems = photoItems.map { item in
            var updated = item
            updated.displayImage = processImage(item.originalImage, cropRect: item.cropRect)
            return updated
        }
    }

    private func generatePDF() {
        isGenerating = true
        let images = photoItems.map(\.displayImage)

        Task {
            // PDF生成をバックグラウンドで開始
            let pdfTask = Task.detached {
                PDFGenerator.generatePDF(from: images)
            }

            // 広告を表示（PDF生成と並行）
            await withCheckedContinuation { continuation in
                adManager.showAd {
                    continuation.resume()
                }
            }

            // PDF生成の完了を待つ（広告中に終わっていれば即完了）
            pdfData = await pdfTask.value
            isGenerating = false
            showPreview = true
        }
    }
}

#Preview {
    ContentView()
}

#else
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("このアプリはiOS/iPadOS専用です")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
