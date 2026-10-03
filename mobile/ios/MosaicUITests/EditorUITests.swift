import XCTest

final class EditorUITests: XCTestCase {
    @MainActor func testImportChangeRatioAndShare() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-language", "vi"]
        app.launch()
        let addPhoto = app.buttons["Thêm ảnh"].firstMatch
        XCTAssertTrue(addPhoto.waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Mosaic native editor"; screenshot.lifetime = .keepAlways; add(screenshot)
        addPhoto.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10))
        let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo,'"))
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 30))
        photos.element(boundBy: 0).tap()
        photos.element(boundBy: 1).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Ảnh 1"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Ảnh 2"].exists)
        let imported = XCTAttachment(screenshot: app.screenshot()); imported.name = "Imported photos"; imported.lifetime = .keepAlways; add(imported)
        let ratio = app.buttons["16:9"]
        for _ in 0..<8 { if ratio.isHittable { break }; app.swipeUp() }
        ratio.tap()
        let export = app.buttons["Xuất và chia sẻ ảnh 4K"]
        for _ in 0..<12 { if export.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(export.isEnabled); export.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 15))
        let shared = XCTAttachment(screenshot: app.screenshot()); shared.name = "Native share sheet"; shared.lifetime = .keepAlways; add(shared)

    }
}
