import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct CollageTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
    static func photo() -> Photo {
        // Explicit top red / bottom blue rows catch accidentally flipped AppKit exports.
        let bytes: [UInt8] = [255,0,0,255, 255,0,0,255, 0,0,255,255, 0,0,255,255]
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return Photo(image: image, name: "Fixture")
    }
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        expect(GeometryBridge.layouts().count == 36, "Layout catalog")
        for layout in GeometryBridge.layouts() {
            var c = Collage(); c.layout = layout["id"]!; c.photos = Array(repeating: photo(), count: 24); c.border = 120
            for ratio in [0.2, 1, 5] {
                c.ratio = ratio; let cells = c.geometry(c.outputSize)
                expect(cells.count == 24 && cells.allSatisfy { !$0.isEmpty && $0.boundingBoxOfPath.width > 0 }, "36 layouts × extreme ratios")
            }
        }
        var collage = Collage(); collage.photos = [photo()]; collage.border = 0
        let box = CGRect(x: 13, y: 29, width: 300, height: 700)
        for zoom in [1.0, 2, 4] { for x in [0.0, 0.5, 1] { for y in [0.0, 0.5, 1] {
            var p = photo(); p.zoom = zoom; p.x = x; p.y = y
            expect(collage.placement(p, in: box).contains(box), "Crop containment")
        } } }
        for png in [true, false] {
            let url = directory.appendingPathComponent(png ? "test.png" : "test.jpg")
            try collage.export(to: url, png: png)
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            expect(image.width == 3840 && image.height == 3840, "Export is 4K")
            let context = bitmapContext(2, 2)!; context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: 2, height: 2))
            let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
            expect(pixels[0] > 240 && pixels[2] < 15 && pixels[8] < 15 && pixels[10] > 240, "Export orientation and colors")
            let decoded = try PhotoDecoder.decode(url, maxPixels: 40_000)
            expect(decoded.width * decoded.height <= 40_000, "Decode pixel budget")
        }
        collage.ratio = 5
        let small = collage.geometry(CGSize(width: 1037, height: 207))[0].boundingBoxOfPath
        let large = collage.geometry(collage.outputSize)[0].boundingBoxOfPath
        expect(abs(small.width / 1037 - large.width / collage.outputSize.width) < 1e-9, "Preview/export agreement")
        let model = EditorModel(); model.collage.photos = [photo(), photo()]
        let first = model.collage.photos[0].id
        model.move(1); expect(model.selected == 1 && model.collage.photos[1].id == first, "Reorder")
        model.remove(); model.remove(); expect(model.collage.photos.isEmpty && model.selected == 0, "Remove to empty")
        let fixture = directory.appendingPathComponent("fixture.png"); try collage.export(to: fixture, png: true)
        await model.load([fixture], vi: false); expect(model.collage.photos.count == 1, "Async import")
        let rotated = directory.appendingPathComponent("rotated.jpg")
        let destination = CGImageDestinationCreateWithURL(rotated as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        let image = bitmapContext(800, 400)!.makeImage()!
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
        expect(CGImageDestinationFinalize(destination), "EXIF fixture")
        let decoded = try PhotoDecoder.decode(rotated, maxPixels: 80_000)
        expect(decoded.width == 200 && decoded.height == 400, "EXIF rotation and downsampling")
        print("PASS: macOS catalog, 108 extreme layouts, crop, PNG/JPG pixels/orientation, decode budget, EXIF, preview, reorder/remove and async import")
    }
}
