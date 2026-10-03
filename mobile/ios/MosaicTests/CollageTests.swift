import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Mosaic

final class CollageTests: XCTestCase {
    func photo(_ color: UIColor, width: CGFloat = 240, height: CGFloat = 120) -> Photo {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return Photo(image: UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        })
    }
    func testAllLayoutsBridgeAndPreserveCells() {
        XCTAssertEqual(GeometryBridge.layouts().count, 36)
        for layout in GeometryBridge.layouts() {
            var collage = Collage(); collage.layout = layout["id"]!; collage.photos = Array(repeating: photo(.red), count: 24); collage.border = 120
            for ratio in [0.2, 1, 5] {
                collage.ratio = ratio
                let geometry = collage.geometry(collage.outputSize)
                XCTAssertEqual(geometry.cells.count, 24)
                XCTAssertTrue(geometry.cells.allSatisfy { !$0.isEmpty && $0.boundingBoxOfPath.width > 0 && $0.boundingBoxOfPath.height > 0 })
            }
        }
    }
    func testCropContainsCellAtEveryZoomAndEdge() {
        let collage = Collage()
        for zoom in [1.0, 2, 4] { for x in [0.0, 0.5, 1] { for y in [0.0, 0.5, 1] {
            var p = photo(.red); p.zoom = zoom; p.x = x; p.y = y
            let box = CGRect(x: 23, y: 41, width: 130, height: 420)
            XCTAssertTrue(collage.placement(p, in: box).contains(box))
        } } }
    }
    func testPNGAndJPEGExportDimensionsAndColors() throws {
        var collage = Collage(); collage.photos = [photo(.red), photo(.blue)]; collage.layout = "columns"; collage.border = 0; collage.ratio = 16.0/9
        for png in [true, false] {
            let url = try collage.export(png: png); defer { try? FileManager.default.removeItem(at: url) }
            let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
            XCTAssertEqual(image.width, 3840); XCTAssertEqual(image.height, 2160)
            let bytes = try XCTUnwrap(image.dataProvider?.data) as Data
            XCTAssertGreaterThan(bytes.count, 0)
            // Normalize to RGBA to avoid depending on encoder byte order.
            var pixels = [UInt8](repeating: 0, count: 8)
            let space = CGColorSpaceCreateDeviceRGB()
            let context = try XCTUnwrap(CGContext(data: &pixels, width: 2, height: 1, bitsPerComponent: 8, bytesPerRow: 8, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.interpolationQuality = .none; context.draw(image, in: CGRect(x: 0, y: 0, width: 2, height: 1))
            XCTAssertGreaterThan(pixels[0], 240); XCTAssertLessThan(pixels[2], 15)
            XCTAssertLessThan(pixels[4], 15); XCTAssertGreaterThan(pixels[6], 240)
        }
    }
    @MainActor func testEditorReorderRemoveAndReset() {
        let model = EditorModel(); model.collage.photos = [photo(.red), photo(.blue)]
        model.collage.photos[0].zoom = 4; model.collage.photos[0].x = 0
        let first = model.collage.photos[0].id
        model.move(1); XCTAssertEqual(model.selected, 1); XCTAssertEqual(model.collage.photos[1].id, first)
        model.move(-1); XCTAssertEqual(model.selected, 0)
        model.resetCrops()
        XCTAssertEqual(model.collage.photos[0].zoom, 1); XCTAssertEqual(model.collage.photos[0].x, 0.5)
        model.remove(); XCTAssertEqual(model.collage.photos.count, 1); XCTAssertEqual(model.selected, 0)
        model.remove(); XCTAssertTrue(model.collage.photos.isEmpty); model.remove()
    }
    func testDecodeOrientationAndPixelBudget() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, photo(.red, width: 800, height: 400).image.cgImage!, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let decoded = try PhotoDecoder.decode(url, maxPixels: 80_000)
        XCTAssertEqual(decoded.size.width, 200); XCTAssertEqual(decoded.size.height, 400)
    }
    func testPreviewGeometryMatchesExportEvenAtRoundedViewSizes() {
        var collage = Collage(); collage.photos = [photo(.red), photo(.blue)]; collage.ratio = 5
        let size = CGSize(width: 1037, height: 207)
        let preview = collage.geometry(size).cells
        let full = collage.geometry(collage.outputSize).cells
        for (small, large) in zip(preview, full) {
            XCTAssertEqual(small.boundingBoxOfPath.minX / size.width, large.boundingBoxOfPath.minX / collage.outputSize.width, accuracy: 1e-9)
            XCTAssertEqual(small.boundingBoxOfPath.height / size.height, large.boundingBoxOfPath.height / collage.outputSize.height, accuracy: 1e-9)
        }
    }
}
