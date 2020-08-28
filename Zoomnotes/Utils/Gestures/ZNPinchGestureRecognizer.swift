//
//  ZNTapGestureRecognizer.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

final class ZNPinchGestureRecognizer : UIPinchGestureRecognizer {
    typealias Callback = (ZNPinchGestureRecognizer) -> Void
    private var action: Callback
    
    init(action: @escaping Callback) {
        self.action = action
        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(execute))
    }

    @objc private func execute(_ recognizer: ZNPinchGestureRecognizer) {
        action(self)
    }
}
