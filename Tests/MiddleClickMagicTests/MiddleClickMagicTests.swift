import Testing
@testable import MiddleClickMagicCore

@Test func normalizedCenterTouchConverts() {
    let detector = MiddleClickDetector()
    let touch = TouchSample(x: 0.5, y: 0.4, capturedAtUptime: 10.0)

    #expect(detector.shouldConvertToMiddleClick(touches: [touch], now: 10.05))
}

@Test func normalizedSideTouchDoesNotConvert() {
    let detector = MiddleClickDetector()
    let touch = TouchSample(x: 0.85, y: 0.4, capturedAtUptime: 10.0)

    #expect(!detector.shouldConvertToMiddleClick(touches: [touch], now: 10.05))
}

@Test func signedCenterTouchConverts() {
    let detector = MiddleClickDetector()
    let touch = TouchSample(x: -0.03, y: 0.1, capturedAtUptime: 10.0)

    #expect(detector.shouldConvertToMiddleClick(touches: [touch], now: 10.05))
}

@Test func staleTouchDoesNotConvert() {
    let detector = MiddleClickDetector()
    let touch = TouchSample(x: 0.5, y: 0.4, capturedAtUptime: 10.0)

    #expect(!detector.shouldConvertToMiddleClick(touches: [touch], now: 11.0))
}

@Test func wideAreaAcceptsWiderNormalizedTouch() {
    let detector = MiddleClickDetector(
        settings: MiddleClickSettings(centerWidth: MiddleClickSettings.wideCenterWidth)
    )
    let touch = TouchSample(x: 0.66, y: 0.4, capturedAtUptime: 10.0)

    #expect(detector.shouldConvertToMiddleClick(touches: [touch], now: 10.05))
}
