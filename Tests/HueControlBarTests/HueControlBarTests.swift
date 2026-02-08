import XCTest
@testable import HueControlBar

final class HueControlBarTests: XCTestCase {
    func testInitDoesNotCrash() {
        let bar = HueControlBar()
        XCTAssertNotNil(bar)
    }
}
