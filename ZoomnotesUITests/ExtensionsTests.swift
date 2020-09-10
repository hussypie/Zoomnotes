//
//  ExtensionsTests.swift
//  ZoomnotesUITests
//
//  Created by Berci on 2020. 09. 10..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import SwiftCheck

class ExtensionsTests: XCTestCase {

    func testUserDefaultsWithDefaultsMissingKey() {
        let mockUserDefaults = UserDefaults()
        property("For any key not set in defaults, the default value is returned") <- forAll { (key: String, defaultValue: Int) in
            return mockUserDefaults.withDefault(forKey: key, default: defaultValue) == defaultValue
        }
    }

    func testUserDefaultsWithDefaultsAddedKey() {
        let mockUserDefaults = UserDefaults()
        property("For any key that is set in defaults, the set value is returned") <- forAll { (key: String, value: Int, defaultValue: Int) in
            return (value != defaultValue ==> {
                mockUserDefaults.set(value, forKey: key)
                return mockUserDefaults.withDefault(forKey: key, default: defaultValue) == value
            })
        }
    }

}
