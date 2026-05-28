//
//  ScreenshotTests.swift
//  Aura Birthday PrototypeUITests
//
// Captures screenshots of key UI states and attaches them to the Xcode test report.
//
// HOW TO ACCESS RESULTS:
//   1. Run this test (Cmd+U or click the diamond next to testCaptureAllStates)
//   2. Open the Report navigator (Cmd+9), find the test run, click testCaptureAllStates
//   3. Expand "Attachments" in the right panel to see each screenshot
//   4. Right-click any screenshot → Export to save as PNG

import XCTest

final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Walks through all major UI states and attaches a screenshot at each one.
    /// Total runtime: ~10 seconds.
    @MainActor
    func testCaptureAllStates() throws {
        app.launch()

        // State 1: Cards beginning to animate in (~1.5s in)
        Thread.sleep(forTimeInterval: 1.5)
        screenshot("01-home-cards-animating-in")

        // State 2: All cards fully visible, "Get started" button ready (~2.0s in)
        // Cards bloom starts at ~2.5s so this catches the fully-settled grid.
        Thread.sleep(forTimeInterval: 0.5)
        screenshot("02-home-cards-fully-visible")

        // State 3: Placeholder video card visible (cards have animated out, ~5.5s in)
        Thread.sleep(forTimeInterval: 3.5)
        screenshot("03-home-placeholder-card")

        // Tap the placeholder card to open the editor directly
        let cardArea = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        cardArea.tap()
        Thread.sleep(forTimeInterval: 1.2)

        // State 4: Editor — default view, drawer collapsed
        screenshot("04-editor-drawer-collapsed")

        // Swipe up from the drawer to expand it
        let drawerStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let drawerEnd   = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        drawerStart.press(forDuration: 0.05, thenDragTo: drawerEnd)
        Thread.sleep(forTimeInterval: 0.9)

        // State 5: Editor — drawer expanded, slide grid visible
        screenshot("05-editor-drawer-expanded")

        // Tap the video area (top half) to enter fullscreen preview
        let videoArea = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        videoArea.tap()
        Thread.sleep(forTimeInterval: 0.8)

        // State 6: Editor — fullscreen video / preview mode
        screenshot("06-editor-fullscreen-preview")
    }

    private func screenshot(_ name: String) {
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
