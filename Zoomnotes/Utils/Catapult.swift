//
//  Catapult.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

struct Catapult {
    let flingThreshold: CGFloat
    let view: UIView
    let done: () -> Void

    init(threshold: CGFloat, in view: UIView, done: @escaping () -> Void) {
        self.flingThreshold = threshold
        self.view = view
        self.done = done
    }

    func tryFling(_ velocity: CGPoint, _ magnitude: CGFloat, _ preview: NoteLevelPreview) -> Bool {

        if magnitude < flingThreshold { return false }

        let velocityPadding: CGFloat  = 35
        let animator = UIDynamicAnimator(referenceView: view)
        let pushBehavior = UIPushBehavior(items: [preview], mode: .instantaneous)
        pushBehavior.pushDirection = CGVector(dx: velocity.x / 10, dy: velocity.y / 10)
        pushBehavior.magnitude = magnitude / velocityPadding

        animator.addBehavior(pushBehavior)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            animator.removeAllBehaviors()
            self.done()
        }

        return true
    }
}
