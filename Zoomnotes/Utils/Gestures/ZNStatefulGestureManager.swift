//
//  ZNStatefulGestureManager.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

final class ZNStatefulGestureManager<State, Recognizer: UIGestureRecognizer> {
    typealias Begin = (Recognizer) -> State
    typealias Step = (Recognizer, State) -> State
    typealias End = (Recognizer, State) -> Void

    let begin: Begin
    let step: Step
    let end: End

    private var state: State?

    init(begin: @escaping Begin,
         step: @escaping Step,
         end: @escaping End) {
        self.begin = begin
        self.step = step
        self.end = end

        self.state = nil
    }

    func `do`(_ recognizer: Recognizer) {
        if recognizer.state == .began {
            self.state = self.begin(recognizer)
        }

        if recognizer.state == .changed {
            precondition(self.state != nil)
            self.state = self.step(recognizer, self.state!)
        }

        if recognizer.state == .ended && recognizer.state != .cancelled {
            precondition(self.state != nil)
            self.end(recognizer, self.state!)
            self.state = nil
        }
    }
}
