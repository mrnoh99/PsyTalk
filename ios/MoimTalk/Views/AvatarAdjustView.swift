import SwiftUI
import UniformTypeIdentifiers

/// PhotosPicker → UIImage (HEIC 등 Data 직접 로드 실패 방지)
struct PickedPhoto: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw NSError(domain: "PickedPhoto", code: 1)
            }
            return PickedPhoto(image: image)
        }
    }
}

// =====================================================================
//  프로필 사진 조절 — Android AvatarAdjustDialog 미러링
//  사진 선택 후 확대·이동 → 정사각형 크롭 → 확인 시 썸네일 반영
// =====================================================================
struct AvatarAdjustView: View {
    let sourceImage: UIImage
    let onDismiss: () -> Void
    let onConfirm: (Data) -> Void

    @State private var scale: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var cropSize: CGFloat = 280
    @GestureState private var magnifyBy: CGFloat = 1
    @GestureState private var dragBy = CGSize.zero

    private let maxScale: CGFloat = 4

    private var effectiveScale: CGFloat {
        min(maxScale, max(1, scale * magnifyBy))
    }

    private var effectiveOffset: CGSize {
        CGSize(width: offset.width + dragBy.width, height: offset.height + dragBy.height)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("사진 조절")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text("사진을 확대·이동해 원하는 영역을 맞춘 뒤 확인하세요.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                GeometryReader { geo in
                    let box = min(geo.size.width, geo.size.height) * 0.88
                    AvatarAdjustCanvas(
                        image: sourceImage,
                        scale: effectiveScale,
                        offset: effectiveOffset
                    )
                    .frame(width: box, height: box)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .updating($dragBy) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                offset = CGSize(
                                    width: offset.width + value.translation.width,
                                    height: offset.height + value.translation.height
                                )
                            }
                            .simultaneously(with:
                                MagnificationGesture()
                                    .updating($magnifyBy) { value, state, _ in state = value }
                                    .onEnded { value in
                                        scale = min(maxScale, max(1, scale * value))
                                    }
                            )
                    )
                    .onAppear { cropSize = box }
                    .onChange(of: geo.size.width) { _ in cropSize = box }
                }

                HStack(spacing: 12) {
                    Button("취소", action: onDismiss)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Button {
                        if let data = exportAvatarCrop(
                            image: sourceImage,
                            cropSize: cropSize,
                            userScale: effectiveScale,
                            offset: effectiveOffset
                        ) {
                            onConfirm(data)
                        }
                    } label: {
                        Text("확인")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Moim.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(cropSize <= 0)
                }
                .padding(.bottom, 8)
            }
            .padding(20)
        }
    }
}

private struct AvatarAdjustCanvas: View {
    let image: UIImage
    let scale: CGFloat
    let offset: CGSize

    var body: some View {
        Canvas { context, size in
            guard let cg = image.cgImage else { return }
            let bmpW = CGFloat(cg.width)
            let bmpH = CGFloat(cg.height)
            let baseScale = max(size.width / bmpW, size.height / bmpH)
            let totalScale = baseScale * scale
            let scaledW = bmpW * totalScale
            let scaledH = bmpH * totalScale
            let left = size.width / 2 - scaledW / 2 + offset.width
            let top = size.height / 2 - scaledH / 2 + offset.height
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            context.draw(
                Image(decorative: cg, scale: 1),
                in: CGRect(x: left, y: top, width: scaledW, height: scaledH)
            )
        }
        .background(Color.black)
    }
}

/// 자르기 없이 중앙 정사각 썸네일(web 방식: 선택 즉시 사용) — 512px JPEG
func squareThumbnailData(_ image: UIImage, outSize: CGFloat = 512) -> Data? {
    guard let cg = image.cgImage else { return image.jpegData(compressionQuality: 0.85) }
    let w = CGFloat(cg.width), h = CGFloat(cg.height)
    let side = min(w, h)
    let scale = outSize / side
    let drawW = w * scale, drawH = h * scale
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: outSize, height: outSize), format: format)
    let result = renderer.image { _ in
        image.draw(in: CGRect(x: (outSize - drawW) / 2, y: (outSize - drawH) / 2, width: drawW, height: drawH))
    }
    return result.jpegData(compressionQuality: 0.85)
}

private func exportAvatarCrop(
    image: UIImage,
    cropSize: CGFloat,
    userScale: CGFloat,
    offset: CGSize,
    outSize: CGFloat = 512
) -> Data? {
    guard cropSize > 0, let cg = image.cgImage else { return nil }
    let bmpW = CGFloat(cg.width)
    let bmpH = CGFloat(cg.height)
    let baseScale = max(cropSize / bmpW, cropSize / bmpH)
    let totalScale = baseScale * userScale
    let scaledW = bmpW * totalScale
    let scaledH = bmpH * totalScale
    let left = cropSize / 2 - scaledW / 2 + offset.width
    let top = cropSize / 2 - scaledH / 2 + offset.height
    let ratio = outSize / cropSize

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: outSize, height: outSize), format: format)
    let result = renderer.image { ctx in
        UIColor.black.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: outSize, height: outSize))
        ctx.cgContext.saveGState()
        ctx.cgContext.translateBy(x: left * ratio, y: top * ratio)
        ctx.cgContext.scaleBy(x: totalScale * ratio, y: totalScale * ratio)
        ctx.cgContext.draw(cg, in: CGRect(x: 0, y: 0, width: bmpW, height: bmpH))
        ctx.cgContext.restoreGState()
    }
    return result.jpegData(compressionQuality: 0.9)
}
