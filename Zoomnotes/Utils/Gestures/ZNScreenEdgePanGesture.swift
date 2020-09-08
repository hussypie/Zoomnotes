//
//  ZNScreenEdgePanGesture.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

final class ZNScreenEdgePanGesture<State>: UIScreenEdgePanGestureRecognizer {
    typealias StateManager = ZNStatefulGestureManager<State, UIScreenEdgePanGestureRecognizer>
    private let stateManager: StateManager
    init(begin: @escaping StateManager.Begin,
         step: @escaping StateManager.Step,
         end: @escaping StateManager.End) {
        self.stateManager = StateManager(begin: begin, step: step, end: end)

        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(execute))
    }

    @objc private func execute(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        self.stateManager.do(recognizer)
    }
}
