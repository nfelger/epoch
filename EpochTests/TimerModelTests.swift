import XCTest
@testable import Epoch

@MainActor
final class TimerModelTests: XCTestCase {
    var model: TimerModel!

    override func setUp() {
        super.setUp()
        model = TimerModel()
    }

    override func tearDown() {
        model.cancel()
        model = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(model.state, .inactive)
        XCTAssertEqual(model.remaining, 0)
        XCTAssertNil(model.endDate)
    }

    func testStartWithValidDuration() {
        model.start(duration: 300) // 5 minutes
        XCTAssertEqual(model.state, .running)
        XCTAssertNotNil(model.endDate)
        XCTAssertEqual(model.totalDuration, 300)
        XCTAssertEqual(model.remaining, 300, accuracy: 1)
    }

    func testStartRejectsDurationUnder60() {
        model.start(duration: 59)
        XCTAssertEqual(model.state, .inactive)
        XCTAssertNil(model.endDate)
    }

    func testStartAccepts60Seconds() {
        model.start(duration: 60)
        XCTAssertEqual(model.state, .running)
    }

    func testCancel() {
        model.start(duration: 120)
        model.cancel()
        XCTAssertEqual(model.state, .inactive)
        XCTAssertEqual(model.remaining, 0)
        XCTAssertNil(model.endDate)
    }

    func testAdjustRemainingToZeroFinishes() {
        model.start(duration: 300)
        model.adjustRemaining(to: 0)
        XCTAssertEqual(model.state, .finished)
    }

    func testAdjustRemainingNegativeFinishes() {
        model.start(duration: 300)
        model.adjustRemaining(to: -10)
        XCTAssertEqual(model.state, .finished)
    }

    func testAdjustRemainingUpdatesEndDate() {
        model.start(duration: 300)
        let oldEndDate = model.endDate
        model.adjustRemaining(to: 120)
        XCTAssertNotEqual(model.endDate, oldEndDate)
        XCTAssertEqual(model.remaining, 120, accuracy: 1)
    }

    func testAdjustRemainingIgnoredWhenInactive() {
        model.adjustRemaining(to: 100)
        XCTAssertEqual(model.state, .inactive)
        XCTAssertEqual(model.remaining, 0)
    }

    func testCancelFromInactiveIsNoOp() {
        model.cancel()
        XCTAssertEqual(model.state, .inactive)
    }
}
