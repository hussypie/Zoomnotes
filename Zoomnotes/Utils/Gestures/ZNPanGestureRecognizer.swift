//
//  GestureRecognizer+Closure.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

final class ZNPanGestureRecognizer : UIPanGestureRecognizer {
    typealias Callback = (ZNPanGestureRecognizer) -> Void
    private var action: Callback
    
    init(action: @escaping Callback) {
        self.action = action
        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(execute))
    }

    @objc private func execute(_ recognizer: ZNPanGestureRecognizer) {
        action(self)
    }
}
