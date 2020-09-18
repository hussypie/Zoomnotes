//
//  XCTestCase+asynch.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 15..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import XCTest

extension XCTestCase {
//    enum AccessType {
//        case read
//        case write
//    }
//
//    func asynchronously<T>(access: AccessType, _ action: () throws -> T) -> T {
//        let expectation: XCTestExpectation
//
//        switch access {
//        case .read:
//            expectation = self.expectation(description: "Do it!")
//        case .write:
//             expectation = self.expectation(forNotification: .NSManagedObjectContextDidSave, object: self.moc) { _ in return true }
//        }
//
//        do {
//            let result = try action()
//            if access == .read {
//                expectation.fulfill()
//            }
//            self.waitForExpectations(timeout: 2.0) { error in XCTAssertNil(error)}
//            return result
//        } catch let error {
//            XCTFail(error.localizedDescription)
//            fatalError(error.localizedDescription)
//        }
//    }
}
