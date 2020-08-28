//
//  ZNTapGestureRecognizer.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

final class ZNSwipeGestureRecognizer : UISwipeGestureRecognizer {
    typealias Callback = (ZNSwipeGestureRecognizer) -> Void
    private var action: Callback
    
    init(direction: Direction, action: @escaping Callback) {
        self.action = action
        super.init(target: nil, action: nil)
        self.direction = direction
        self.addTarget(self, action: #selector(execute))
    }

    @objc private func execute(_ recognizer: ZNPinchGestureRecognizer) {
        action(self)
    }
}
