//
//  ZoomnotesTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import SwiftCheck
import Combine
@testable import Zoomnotes

class ZoomnotesUtilsTests: XCTestCase {
    func testUserDefaultsWithDefaultsMissingKey() {
        let mockUserDefaults = UserDefaults.mock(name: #file)
        property("For any key not set in defaults, the default value is returned") <- forAll { (key: String, defaultValue: Int) in
            return mockUserDefaults.withDefaultValue(key, default: defaultValue) == defaultValue
        }
    }

    func testUserDefaultsWithDefaultsAddedKey() {
        let mockUserDefaults = UserDefaults()
        property("For any key that is set in defaults, the set value is returned") <- forAll { (key: String, value: Int, defaultValue: Int) in
            return (value != defaultValue ==> {
                mockUserDefaults.set(value, forKey: key)
                return mockUserDefaults.withDefaultValue(key, default: defaultValue) == value
            })
        }
    }

    func testCGRectHalf() {
        property("Point is in right half of CGRect if x coord greater than midX, else is in left half")
            <- forAll { (x: Double, y: Double, width: Double, height: Double, px: Double, py: Double) in
                return ((width >= 0 && height >= 0
                            && px >= x && py >= y
                            && px <= x + width && py <= y + height) ==> {
                    let touchPoint = CGPoint(x: px, y: py)
                    let rect = CGRect(x: x, y: y, width: width, height: height)

                    if touchPoint.x < rect.midX {
                        return rect.half(of: touchPoint) == .left
                    } else {
                        return rect.half(of: touchPoint) == .right
                    }
                })
        }
    }

    func testCGRectCenter() {
        property("CGRect center is a CGPoint of the midX and midY of the rect")
            <- forAll { (x: Double, y: Double, width: Double, height: Double) in
                let rect = CGRect(x: x, y: y, width: width, height: height)
                let center = rect.center

                return rect.midX == center.x && rect.midY == center.y
        }
    }

    func testClamp() {
        property("a clamped value is itself when between lower and upper, otherwise at elast lower and at most upper")
            <- forAll { (x: Int, lower: Int, upper: Int) in
                return ((lower < upper) ==> {
                    let clamped = clamp(x, lower: lower, upper: upper)
                    if x < lower {
                        return clamped == lower
                    } else if x > upper {
                        return clamped == upper
                    } else {
                        return clamped == x
                    }
                })
        }
    }

    func testHalfOpposite() {
        XCTAssert(Half.left.opposite  == .right)
        XCTAssert(Half.right.opposite == .left)
    }

    func testStringEmptyIsEmpty() {
        XCTAssertEqual(String.empty.count, 0)
        XCTAssertEqual(String.empty, "")
    }

    enum TestError: Error { case error }

    func testSink3() {
        _ = Just(3).sink(receiveDone: { XCTAssertTrue(true, "OK")},
                                       receiveError: { _ in },
                                       receiveValue: { XCTAssertEqual($0, 3)})

        _ = Fail<Never, ZoomnotesUtilsTests.TestError>(error: TestError.error)
            .sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTAssertEqual($0, TestError.error) },
               receiveValue: { _ in })

    }
}
