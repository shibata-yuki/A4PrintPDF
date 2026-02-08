//
//  CropView.swift
//  A4PrintPDF
//

#if canImport(UIKit)
import SwiftUI

struct CropView: View {
    let image: UIImage
    let initialCropRect: CGRect?
    var onApply: (CGRect) -> Void
    var onCancel: () -> Void

    // クロップ範囲を正規化座標（0...1）で保持 → imageFrame 変更に自動追従
    @State private var normCrop: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var imageFrame: CGRect = .zero
    @State private var isReady = false

    // ジェスチャー状態
    @State private var isDragging = false
    @State private var dragStartNormCrop: CGRect = .zero
    @State private var dragFixedCornerNorm: CGPoint? = nil

    private let handleRadius: CGFloat = 14
    private let handleHitRadius: CGFloat = 30
    private let minCropDim: CGFloat = 40

    /// 正規化座標 → 画面座標に変換（表示用）
    private var screenCrop: CGRect {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return .zero }
        return CGRect(
            x: imageFrame.minX + normCrop.minX * imageFrame.width,
            y: imageFrame.minY + normCrop.minY * imageFrame.height,
            width: normCrop.width * imageFrame.width,
            height: normCrop.height * imageFrame.height
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { outerGeo in
                ZStack {
                    Color.black

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .background(
                            GeometryReader { imageGeo in
                                Color.clear
                                    .onAppear { measureImage(imageGeo) }
                                    .onChange(of: imageGeo.size) { measureImage(imageGeo) }
                                    .onChange(of: outerGeo.size) { measureImage(imageGeo) }
                            }
                        )

                    if isReady {
                        cropCanvas
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(cropDragGesture)
                    }
                }
                .coordinateSpace(name: "cc")
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") { applyCrop() }
                }
            }
        }
    }

    // MARK: - Canvas

    private var cropCanvas: some View {
        Canvas { context, size in
            let sc = screenCrop

            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.black.opacity(0.5)))
            context.blendMode = .destinationOut
            context.fill(Path(sc), with: .color(.white))

            context.blendMode = .normal
            context.stroke(Path(sc), with: .color(.white), lineWidth: 2)

            for corner in screenCorners(of: sc) {
                let r = handleRadius
                let rect = CGRect(x: corner.x - r, y: corner.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }

    private func screenCorners(of rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ]
    }

    // MARK: - 初期化・測定

    private func measureImage(_ geo: GeometryProxy) {
        let f = geo.frame(in: .named("cc"))
        guard f.width > 0, f.height > 0 else { return }
        imageFrame = f
        if !isReady {
            normCrop = initialCropRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            isReady = true
        }
    }

    private func applyCrop() {
        onApply(CGRect(
            x: max(0, min(1, normCrop.minX)),
            y: max(0, min(1, normCrop.minY)),
            width: max(0.01, min(1, normCrop.width)),
            height: max(0.01, min(1, normCrop.height))
        ))
    }

    // MARK: - 座標変換

    private func toNorm(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - imageFrame.minX) / imageFrame.width,
            y: (screenPoint.y - imageFrame.minY) / imageFrame.height
        )
    }

    // MARK: - ジェスチャー

    private var cropDragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("cc"))
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartNormCrop = normCrop
                    dragFixedCornerNorm = nil

                    let start = value.startLocation
                    let sc = screenCrop

                    // コーナー判定（画面座標で判定、対角を正規化座標で保持）
                    let pairs: [(screen: CGPoint, normOpposite: CGPoint)] = [
                        (CGPoint(x: sc.minX, y: sc.minY), CGPoint(x: normCrop.maxX, y: normCrop.maxY)),
                        (CGPoint(x: sc.maxX, y: sc.minY), CGPoint(x: normCrop.minX, y: normCrop.maxY)),
                        (CGPoint(x: sc.minX, y: sc.maxY), CGPoint(x: normCrop.maxX, y: normCrop.minY)),
                        (CGPoint(x: sc.maxX, y: sc.maxY), CGPoint(x: normCrop.minX, y: normCrop.minY)),
                    ]

                    for pair in pairs {
                        if hypot(start.x - pair.screen.x, start.y - pair.screen.y) < handleHitRadius {
                            dragFixedCornerNorm = pair.normOpposite
                            return
                        }
                    }

                    if !sc.contains(start) {
                        isDragging = false
                        return
                    }
                }

                if let fixedNorm = dragFixedCornerNorm {
                    // リサイズ（正規化座標空間で計算）
                    let clamped = CGPoint(
                        x: max(imageFrame.minX, min(imageFrame.maxX, value.location.x)),
                        y: max(imageFrame.minY, min(imageFrame.maxY, value.location.y))
                    )
                    let norm = toNorm(clamped)

                    let minNW = minCropDim / max(1, imageFrame.width)
                    let minNH = minCropDim / max(1, imageFrame.height)

                    let x1 = min(norm.x, fixedNorm.x)
                    let y1 = min(norm.y, fixedNorm.y)
                    let x2 = max(norm.x, fixedNorm.x)
                    let y2 = max(norm.y, fixedNorm.y)

                    normCrop = CGRect(x: x1, y: y1,
                                      width: max(minNW, x2 - x1),
                                      height: max(minNH, y2 - y1))
                } else if isDragging {
                    // 移動（正規化座標空間で計算）
                    let dx = value.translation.width / imageFrame.width
                    let dy = value.translation.height / imageFrame.height
                    normCrop.origin = CGPoint(
                        x: max(0, min(1 - normCrop.width, dragStartNormCrop.origin.x + dx)),
                        y: max(0, min(1 - normCrop.height, dragStartNormCrop.origin.y + dy))
                    )
                }
            }
            .onEnded { _ in
                isDragging = false
                dragFixedCornerNorm = nil
            }
    }
}
#endif
