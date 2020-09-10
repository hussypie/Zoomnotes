//
//  ZoomnotesTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import SwiftCheck
@testable import Zoomnotes

class ZoomnotesTests: XCTestCase {
    func testUserDefaultsWithDefaultsMissingKey() {
        let mockUserDefaults = UserDefaults()
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
}
