import SwiftUI

struct CircleImageCropperView: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    let onCropComplete: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isProcessing = false

    private let cropDiameter: CGFloat = 280

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Debug: Print image info
            Color.clear
                .onAppear {
                    AppLog.debug("🖼️ [ImageCropper] View appeared")
                    AppLog.debug("   Image size: \(image.size)")
                    AppLog.debug("   Crop diameter: \(cropDiameter)")
                }

            VStack(spacing: 0) {
                // Instructions
                VStack(spacing: 8) {
                    Text("Atur Foto Profil")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Geser dan cubit untuk menyesuaikan posisi foto")
                        .font(AppFont.subheadline())
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)

                // Image Cropper Area
                ZStack {
                        // The image that can be moved and zoomed
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(magnificationGesture)
                            .simultaneousGesture(dragGesture)

                    // Dark overlay with circle hole
                    DarkOverlayWithCircleHole(diameter: cropDiameter)
                        .allowsHitTesting(false)

                    // Circle border
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: cropDiameter, height: cropDiameter)
                        .shadow(color: .black.opacity(0.5), radius: 10)
                        .allowsHitTesting(false)

                    // Dashed circle guide
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [10, 5]))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: cropDiameter + 20, height: cropDiameter + 20)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Action buttons
                HStack(spacing: 16) {
                    // Reset button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                            lastScale = 1.0
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Reset")
                                .font(AppFont.subheadline())
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Crop button
                    Button {
                        cropAndSave()
                    } label: {
                        HStack(spacing: 8) {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Gunakan")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isProcessing)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }

            // Close button overlay (top-left)
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)

                    Spacer()
                }
                Spacer()
            }
        }
    }

    // MARK: - Gestures
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = max(1.0, min(scale * delta, 5.0))
            }
            .onEnded { _ in
                lastScale = 1.0
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func cropAndSave() {
        isProcessing = true

        // Small delay to ensure UI is stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let croppedImage = self.cropImageUsingRender()

            DispatchQueue.main.async {
                self.isProcessing = false
                self.onCropComplete(croppedImage)
                self.dismiss()
            }
        }
    }

    // SIMPLIFIED: Direct crop from original image with proper calculation
    private func cropImageUsingRender() -> UIImage {
        AppLog.debug("🎨 [ImageCropper] Starting crop")
        AppLog.debug("   Original image size: \(image.size)")
        AppLog.debug("   Scale: \(scale), Offset: \(offset)")

        // Normalize image to fix orientation issues
        let normalizedImage = image.fixedOrientation()
        let imageSize = normalizedImage.size

        AppLog.debug("   Normalized image size: \(imageSize)")

        // Screen dimensions
        let screenSize = UIScreen.main.bounds.size
        let imageAspect = imageSize.width / imageSize.height
        let screenAspect = screenSize.width / screenSize.height

        // Calculate how image is displayed with scaledToFit
        var displayWidth: CGFloat
        var displayHeight: CGFloat

        if imageAspect > screenAspect {
            // Width constrained
            displayWidth = screenSize.width
            displayHeight = screenSize.width / imageAspect
        } else {
            // Height constrained
            displayHeight = screenSize.height
            displayWidth = screenSize.height * imageAspect
        }

        // Apply scale
        displayWidth *= scale
        displayHeight *= scale

        AppLog.debug("   Display size (before scale): \(screenSize.width) x \(screenSize.height)")
        AppLog.debug("   Display size (after scale): \(displayWidth) x \(displayHeight)")

        // Image position on screen (centered + offset)
        let imageX = (screenSize.width - displayWidth) / 2 + offset.width
        let imageY = (screenSize.height - displayHeight) / 2 + offset.height

        // Circle center position
        let circleX = screenSize.width / 2
        let circleY = screenSize.height / 2

        // Calculate crop region in display coordinates
        let cropX = circleX - cropDiameter / 2 - imageX
        let cropY = circleY - cropDiameter / 2 - imageY

        AppLog.debug("   Image position: (\(imageX), \(imageY))")
        AppLog.debug("   Crop region (display coords): (\(cropX), \(cropY))")

        // Convert to original image coordinates
        let scaleToOriginal = imageSize.width / displayWidth
        var cropRect = CGRect(
            x: cropX * scaleToOriginal,
            y: cropY * scaleToOriginal,
            width: cropDiameter * scaleToOriginal,
            height: cropDiameter * scaleToOriginal
        )

        AppLog.debug("   Crop rect (original coords): \(cropRect)")

        // Clamp to image bounds
        cropRect.origin.x = max(0, min(cropRect.origin.x, imageSize.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, imageSize.height - cropRect.height))
        cropRect.size.width = min(cropRect.width, imageSize.width - cropRect.origin.x)
        cropRect.size.height = min(cropRect.height, imageSize.height - cropRect.origin.y)

        AppLog.debug("   Clamped crop rect: \(cropRect)")

        // Crop using CGImage
        guard let cgImage = normalizedImage.cgImage else {
            AppLog.debug("❌ [ImageCropper] No CGImage available")
            return normalizedImage
        }

        // Convert UIKit coordinates to Core Graphics coordinates
        let scale = normalizedImage.scale
        let cropRectScaled = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRectScaled) else {
            AppLog.debug("❌ [ImageCropper] CGImage crop failed")
            return normalizedImage
        }

        let croppedImage = UIImage(cgImage: croppedCGImage, scale: scale, orientation: .up)

        // Make circular
        let outputSize = CGSize(width: cropDiameter, height: cropDiameter)
        let renderer = UIGraphicsImageRenderer(size: outputSize)

        let finalImage = renderer.image { context in
            // Create circular path
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: outputSize))
            path.addClip()

            // Draw image
            croppedImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }

        AppLog.debug("✅ [ImageCropper] Crop complete")
        return finalImage
    }

}

// MARK: - Dark Overlay with Circle Hole
struct DarkOverlayWithCircleHole: View {
    let diameter: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Outer rectangle (full screen)
                path.addRect(CGRect(origin: .zero, size: geometry.size))

                // Inner circle (hole)
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let circleRect = CGRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                path.addEllipse(in: circleRect)
            }
            .fill(Color.black.opacity(0.7), style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - UIImage Extension for Orientation Fix
extension UIImage {
    func fixedOrientation() -> UIImage {
        // If image is already correctly oriented, return it
        if imageOrientation == .up {
            return self
        }

        // Create a new image with correct orientation
        guard let cgImage = cgImage else { return self }

        let width = size.width
        let height = size.height

        var transform = CGAffineTransform.identity

        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }

        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        guard let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            return self
        }

        context.concatenate(transform)

        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        guard let newCGImage = context.makeImage() else { return self }

        return UIImage(cgImage: newCGImage, scale: scale, orientation: .up)
    }
}

#Preview {
    if let sampleImage = UIImage(systemName: "photo") {
        CircleImageCropperView(
            image: sampleImage,
            onCropComplete: { _ in }
        )
    }
}
