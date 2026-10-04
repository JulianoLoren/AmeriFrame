import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

struct Photo: Identifiable {
    let id = UUID()
    var image: UIImage
    var x = 0.5
    var y = 0.5
    var zoom = 1.0
}

struct ImportedPhoto: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let size = try received.file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 30 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("mosaic-import-\(UUID().uuidString)")
            try FileManager.default.copyItem(at: received.file, to: url)
            return ImportedPhoto(url: url)
        }
    }
}

enum PhotoDecoder {
    static func decode(_ url: URL, maxPixels: Double) throws -> UIImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double,
              width > 0, height > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let scale = min(1, 3840 / max(width, height), sqrt(maxPixels / (width * height)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(max(width, height) * scale)),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        return UIImage(cgImage: image)
    }
    static func shrink(_ image: UIImage, maxPixels: Double) -> UIImage {
        let pixels = image.size.width * image.size.height
        guard pixels > maxPixels else { return image }
        let scale = sqrt(maxPixels / pixels)
        let size = CGSize(width: max(1, floor(image.size.width * scale)), height: max(1, floor(image.size.height * scale)))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

struct Collage {
    var photos: [Photo] = []
    var layout = "grid"
    var ratio = 1.0
    var border = 24.0
    var color = UIColor.white

    var outputSize: CGSize {
        ratio >= 1 ? CGSize(width: 3840, height: (3840 / ratio).rounded())
                   : CGSize(width: (3840 * ratio).rounded(), height: 3840)
    }
    func geometry(_ size: CGSize) -> (cells: [CGPath], gap: Double) {
        let values = GeometryBridge.frame(layout, count: max(1, photos.count), width: outputSize.width,
                                          height: outputSize.height, gap: border).map(\.doubleValue)
        guard let gap = values.first else { return ([], 0) }
        var paths: [CGPath] = [], index = 1
        while index < values.count {
            let count = Int(values[index]); index += 1
            let path = CGMutablePath()
            for vertex in 0..<count {
                let point = CGPoint(x: values[index] * size.width / outputSize.width, y: values[index + 1] * size.height / outputSize.height); index += 2
                if vertex == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath(); paths.append(path)
        }
        return (paths, gap)
    }
    func placement(_ photo: Photo, in box: CGRect) -> CGRect {
        let scale = max(box.width / photo.image.size.width, box.height / photo.image.size.height) * photo.zoom
        let w = photo.image.size.width * scale, h = photo.image.size.height * scale
        return CGRect(x: box.minX - (w - box.width) * photo.x, y: box.minY - (h - box.height) * photo.y, width: w, height: h)
    }
    // Anchor zoom and pan to a point in the photo, then clamp to keep the frame covered.
    func transformed(_ photo: Photo, in box: CGRect, from anchor: CGPoint, to destination: CGPoint, zoom: Double) -> Photo {
        let before = placement(photo, in: box)
        var result = photo; result.zoom = min(4, max(1, zoom))
        let after = placement(result, in: box)
        let left = destination.x - (anchor.x - before.minX) * after.width / before.width
        let top = destination.y - (anchor.y - before.minY) * after.height / before.height
        result.x = after.width > box.width ? min(1, max(0, (box.minX - left) / (after.width - box.width))) : 0.5
        result.y = after.height > box.height ? min(1, max(0, (box.minY - top) / (after.height - box.height))) : 0.5
        return result
    }
    func draw(_ context: CGContext, size: CGSize, selected: Int? = nil) {
        context.setFillColor(color.cgColor); context.fill(CGRect(origin: .zero, size: size))
        let cells = geometry(size).cells
        for (index, path) in cells.enumerated() where photos.indices.contains(index) {
            context.saveGState(); context.addPath(path); context.clip()
            photos[index].image.draw(in: placement(photos[index], in: path.boundingBoxOfPath))
            context.restoreGState()
            if index == selected {
                context.addPath(path); context.setStrokeColor(UIColor.white.cgColor); context.setLineWidth(3); context.strokePath()
                context.saveGState(); context.addPath(path); context.setLineDash(phase: 0, lengths: [5, 4])
                context.setStrokeColor(UIColor.black.cgColor); context.setLineWidth(1); context.strokePath(); context.restoreGState()
            }
        }
    }
    func export(png: Bool) throws -> URL {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true; format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: outputSize, format: format).image { draw($0.cgContext, size: outputSize) }
        guard let data = png ? image.pngData() : image.jpegData(compressionQuality: 0.96) else { throw CocoaError(.fileWriteUnknown) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MosaicExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Expired shares are temporary; never touch source photos.
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])) ?? [] {
            let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
            if let date, Date().timeIntervalSince(date) > 86_400 { try? FileManager.default.removeItem(at: url) }
        }
        let url = directory.appendingPathComponent("mosaic-\(UUID().uuidString).\(png ? "png" : "jpg")")
        try data.write(to: url, options: .atomic); return url
    }
}

@MainActor
final class EditorModel: ObservableObject {
    @Published var collage = Collage()
    @Published var selected = 0
    @Published var busy = false
    @Published var error: String?
    @Published var shareURL: URL?
    func resetCrops() {
        for i in collage.photos.indices { collage.photos[i].x = 0.5; collage.photos[i].y = 0.5; collage.photos[i].zoom = 1 }
    }
    func move(_ delta: Int) {
        let target = selected + delta
        guard !busy, collage.photos.indices.contains(selected), collage.photos.indices.contains(target) else { return }
        collage.photos.swapAt(selected, target); selected = target
    }
    func remove() {
        guard !busy, collage.photos.indices.contains(selected) else { return }
        collage.photos.remove(at: selected)
        selected = max(0, min(selected, collage.photos.count - 1)); resetCrops()
    }
    func load(_ items: [PhotosPickerItem], vi: Bool) async {
        guard !busy, !items.isEmpty else { return }
        busy = true
        defer { busy = false }
        var failures = 0
        let start = collage.photos.count
        let maxPixels = 24_000_000.0 / Double(min(24, start + items.count))
        // Shrink earlier imports before loading more; retain full detail for small collages.
        for index in collage.photos.indices {
            let image = collage.photos[index].image
            collage.photos[index].image = await Task.detached { PhotoDecoder.shrink(image, maxPixels: maxPixels) }.value
        }
        for item in items.prefix(24 - start) {
            do {
                // Transfer/decode work runs outside the main actor.
                let image = try await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    guard let imported = try await item.loadTransferable(type: ImportedPhoto.self) else { return nil }
                    defer { try? FileManager.default.removeItem(at: imported.url) }
                    return try PhotoDecoder.decode(imported.url, maxPixels: maxPixels)
                }.value
                if let image { collage.photos.append(Photo(image: image)) } else { failures += 1 }
            } catch { failures += 1 }
        }
        if collage.photos.count > start { selected = start; resetCrops() }
        if failures > 0 { error = vi ? "Không đọc được \(failures) ảnh. Tối đa 30 MB/ảnh." : "Could not read \(failures) photos. Maximum 30 MB per photo." }
    }
    func export(png: Bool, vi: Bool) async {
        guard !busy, !collage.photos.isEmpty else { return }
        busy = true; defer { busy = false }
        let snapshot = collage
        do { shareURL = try await Task.detached(priority: .userInitiated) { try snapshot.export(png: png) }.value }
        catch { self.error = vi ? "Không thể xuất ảnh. Hãy thử lại." : "Could not export. Please try again." }
    }
}

struct CollagePreview: UIViewRepresentable {
    let collage: Collage
    let selected: Int
    var enabled = true
    var cropChanged: ((Int, Photo) -> Void)?
    func makeUIView(context: Context) -> Preview { Preview() }
    func updateUIView(_ view: Preview, context: Context) {
        view.collage = collage; view.selected = selected; view.isUserInteractionEnabled = enabled
        view.cropChanged = cropChanged; view.setNeedsDisplay()
    }
    final class Preview: UIView, UIGestureRecognizerDelegate {
        var collage = Collage()
        var selected = 0
        var cropChanged: ((Int, Photo) -> Void)?
        private var active: (index: Int, id: UUID, box: CGRect)?
        private var pinchPoint = CGPoint.zero
        private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panPhoto(_:)))
        private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchPhoto(_:)))
        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            pan.maximumNumberOfTouches = 2
            for recognizer in [pan, pinch] { recognizer.delegate = self; addGestureRecognizer(recognizer) }
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectPhoto(_:))))
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        private func begin(at point: CGPoint) -> Bool {
            let cells = collage.geometry(bounds.size).cells
            guard let index = cells.firstIndex(where: { $0.contains(point) }), collage.photos.indices.contains(index) else { active = nil; return false }
            selected = index; active = (index, collage.photos[index].id, cells[index].boundingBoxOfPath)
            cropChanged?(index, collage.photos[index]); setNeedsDisplay(); return true
        }
        private func change(from: CGPoint, to: CGPoint, scale: Double) {
            guard let a = active, collage.photos.indices.contains(a.index), collage.photos[a.index].id == a.id,
                  collage.geometry(bounds.size).cells[a.index].boundingBoxOfPath == a.box else { active = nil; return }
            let photo = collage.photos[a.index]
            let result = collage.transformed(photo, in: a.box, from: from, to: to, zoom: photo.zoom * scale)
            collage.photos[a.index] = result; cropChanged?(a.index, result); setNeedsDisplay()
        }
        override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            if recognizer === pinch && (pan.state == .began || pan.state == .changed) && active != nil { return true }
            let location = recognizer.location(in: self)
            if recognizer === pan {
                let translation = pan.translation(in: self)
                return begin(at: CGPoint(x: location.x - translation.x, y: location.y - translation.y))
            }
            return begin(at: location)
        }
        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            (recognizer === pan && other === pinch) || (recognizer === pinch && other === pan)
        }
        @objc private func selectPhoto(_ recognizer: UITapGestureRecognizer) { _ = begin(at: recognizer.location(in: self)); active = nil }
        @objc private func panPhoto(_ recognizer: UIPanGestureRecognizer) {
            defer { recognizer.setTranslation(.zero, in: self) }
            guard pinch.state != .began && pinch.state != .changed, recognizer.numberOfTouches == 1 else { return }
            let point = recognizer.location(in: self), delta = recognizer.translation(in: self)
            if recognizer.state == .began || recognizer.state == .changed {
                change(from: CGPoint(x: point.x - delta.x, y: point.y - delta.y), to: point, scale: 1)
            }
        }
        @objc private func pinchPhoto(_ recognizer: UIPinchGestureRecognizer) {
            let point = recognizer.location(in: self)
            if recognizer.state == .began { pinchPoint = point }
            if recognizer.state == .changed {
                change(from: pinchPoint, to: point, scale: recognizer.scale)
            }
            pinchPoint = point; recognizer.scale = 1; pan.setTranslation(.zero, in: self)
        }
        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            collage.draw(context, size: bounds.size, selected: selected)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
