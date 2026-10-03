import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct Photo: Identifiable {
    let id = UUID()
    var image: CGImage
    let name: String
    var x = 0.5
    var y = 0.5
    var zoom = 1.0
}

enum PhotoDecoder {
    static func decode(_ url: URL, maxPixels: Double) throws -> CGImage {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes > 0, bytes <= 30 * 1024 * 1024,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = info[kCGImagePropertyPixelWidth] as? Double,
              let h = info[kCGImagePropertyPixelHeight] as? Double, w > 0, h > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let scale = min(1, 3840 / max(w, h), sqrt(maxPixels / (w * h)))
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(max(w, h) * scale))]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }
    static func shrink(_ image: CGImage, maxPixels: Double) -> CGImage {
        let scale = min(1, sqrt(maxPixels / (Double(image.width) * Double(image.height))))
        guard scale < 1, let context = bitmapContext(max(1, Int(Double(image.width) * scale)), max(1, Int(Double(image.height) * scale))) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
        return context.makeImage() ?? image
    }
}
func bitmapContext(_ width: Int, _ height: Int) -> CGContext? {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
}
struct Collage {
    var photos: [Photo] = []
    var layout = "grid"
    var ratio = 1.0
    var border = 24.0
    var color = NSColor.white
    var outputSize: CGSize { ratio >= 1 ? CGSize(width: 3840, height: (3840 / ratio).rounded()) : CGSize(width: (3840 * ratio).rounded(), height: 3840) }
    func geometry(_ size: CGSize, count: Int? = nil) -> [CGPath] {
        let values = GeometryBridge.frame(layout, count: count ?? max(1, photos.count), width: outputSize.width, height: outputSize.height, gap: border).map(\.doubleValue)
        var paths: [CGPath] = [], index = 1
        while index < values.count {
            let vertices = Int(values[index]); index += 1
            let path = CGMutablePath()
            for vertex in 0..<vertices {
                let p = CGPoint(x: values[index] * size.width / outputSize.width, y: values[index+1] * size.height / outputSize.height); index += 2
                if vertex == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath(); paths.append(path)
        }
        return paths
    }
    func placement(_ photo: Photo, in box: CGRect) -> CGRect {
        let scale = max(box.width / Double(photo.image.width), box.height / Double(photo.image.height)) * photo.zoom
        let w = Double(photo.image.width) * scale, h = Double(photo.image.height) * scale
        return CGRect(x: box.minX-(w-box.width)*photo.x, y: box.minY-(h-box.height)*photo.y, width: w, height: h)
    }
    // Both AppKit preview and export provide a top-left coordinate system.
    func draw(_ context: CGContext, size: CGSize, selected: Int? = nil) {
        context.saveGState(); defer { context.restoreGState() }
        context.clip(to: CGRect(origin: .zero, size: size))
        context.setFillColor(color.cgColor); context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high
        for (index, path) in geometry(size).enumerated() where photos.indices.contains(index) {
            let photo = photos[index], place = placement(photo, in: path.boundingBoxOfPath)
            context.saveGState(); context.addPath(path); context.clip()
            context.translateBy(x: place.minX, y: place.maxY); context.scaleBy(x: 1, y: -1)
            context.draw(photo.image, in: CGRect(origin: .zero, size: place.size)); context.restoreGState()
            if selected == index {
                context.addPath(path); context.setStrokeColor(NSColor.white.cgColor); context.setLineWidth(3); context.strokePath()
                context.saveGState(); context.addPath(path); context.setStrokeColor(NSColor.black.cgColor)
                context.setLineWidth(1); context.setLineDash(phase: 0, lengths: [5,4]); context.strokePath(); context.restoreGState()
            }
        }
    }
    func export(to url: URL, png: Bool) throws {
        guard !photos.isEmpty, let context = bitmapContext(Int(outputSize.width), Int(outputSize.height)) else { throw CocoaError(.fileWriteUnknown) }
        context.translateBy(x: 0, y: outputSize.height); context.scaleBy(x: 1, y: -1)
        draw(context, size: outputSize)
        guard let image = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, (png ? UTType.png : UTType.jpeg).identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.96] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        try (data as Data).write(to: url, options: .atomic)
    }
}

@MainActor final class EditorModel: ObservableObject {
    @Published var collage = Collage()
    @Published var selected = 0
    @Published var busy = false
    @Published var message: String?
    @Published var lastExport: URL?
    func resetCrops() { for i in collage.photos.indices { collage.photos[i].x = 0.5; collage.photos[i].y = 0.5; collage.photos[i].zoom = 1 } }
    func remove() {
        guard !busy, collage.photos.indices.contains(selected) else { return }
        collage.photos.remove(at: selected); selected = max(0, min(selected, collage.photos.count-1)); resetCrops()
    }
    func move(_ delta: Int) {
        guard !busy, collage.photos.indices.contains(selected+delta) else { return }
        collage.photos.swapAt(selected, selected+delta); selected += delta
    }
    func choosePhotos(vi: Bool) {
        guard !busy, collage.photos.count < 24 else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        busy = true
        let completion: (NSApplication.ModalResponse) -> Void = { result in
            self.busy = false
            if result == .OK { Task { await self.load(panel.urls, vi: vi) } }
        }
        if let window = NSApp.mainWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    func load(_ urls: [URL], vi: Bool) async {
        guard !busy, !urls.isEmpty else { return }
        busy = true; defer { busy = false }
        let start = collage.photos.count, maxPixels = 24_000_000.0 / Double(min(24, collage.photos.count + urls.count))
        for index in collage.photos.indices {
            let image = collage.photos[index].image
            collage.photos[index].image = await Task.detached { PhotoDecoder.shrink(image, maxPixels: maxPixels) }.value
        }
        var failed = 0
        for url in urls.prefix(24-start) {
            do {
                let image = try await Task.detached { try PhotoDecoder.decode(url, maxPixels: maxPixels) }.value
                collage.photos.append(Photo(image: image, name: url.lastPathComponent))
            } catch { failed += 1 }
        }
        if collage.photos.count > start { selected = start; resetCrops() }
        if failed > 0 || urls.count > 24-start {
            message = vi ? "Đã thêm \(collage.photos.count-start) ảnh. Tối đa 24 ảnh, 30 MB/ảnh; một số tệp không đọc được hoặc vượt giới hạn." : "Added \(collage.photos.count-start) photos. Limit: 24 photos, 30 MB each; some files were unreadable or exceeded the limit."
        }
    }
    func save(png: Bool, vi: Bool) {
        guard !busy, !collage.photos.isEmpty else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [png ? .png : .jpeg]
        panel.nameFieldStringValue = "mosaic-\(Int(collage.outputSize.width))x\(Int(collage.outputSize.height)).\(png ? "png" : "jpg")"
        busy = true
        let completion: (NSApplication.ModalResponse) -> Void = { result in
            self.busy = false
            guard result == .OK, let url = panel.url else { return }
            Task {
                self.busy = true; defer { self.busy = false }
                let snapshot = self.collage
                do {
                    try await Task.detached { try snapshot.export(to: url, png: png) }.value
                    self.lastExport = url
                } catch { self.message = vi ? "Không thể lưu ảnh. Hãy thử vị trí khác." : "Could not save. Please try another location." }
            }
        }
        if let window = NSApp.mainWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
}

struct CollagePreview: NSViewRepresentable {
    let collage: Collage
    let selected: Int
    func makeNSView(context: Context) -> Preview { Preview() }
    func updateNSView(_ view: Preview, context: Context) { view.collage = collage; view.selected = selected; view.needsDisplay = true }
    final class Preview: NSView {
        var collage = Collage(); var selected = 0
        override var isFlipped: Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            collage.draw(context, size: bounds.size, selected: selected)
        }
    }
}
