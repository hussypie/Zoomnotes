//
//  TransitionDelegate.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 05..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class NoteTransitionDelegate: NSObject, UINavigationControllerDelegate {
    private let interactionController = UIPercentDrivenInteractiveTransition()

    private var downAnimator: UIViewControllerAnimatedTransitioning? = nil
    private var upAnimator: UIViewControllerAnimatedTransitioning? = nil

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .pop:
            self.interactionController.update(0)
            return self.upAnimator
        case .push:
            self.interactionController.update(0)
            return self.downAnimator
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }

    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController
    }

    func step(percent: CGFloat) {
        self.interactionController.update(percent)
    }

    func finish() {
        self.interactionController.finish()
    }

    func cancel() {
        self.interactionController.cancel()
    }

    func down(animator: UIViewControllerAnimatedTransitioning) -> Self {
        self.downAnimator = animator
        return self
    }

    func up(animator: UIViewControllerAnimatedTransitioning) -> Self {
        self.upAnimator = animator
        return self
    }
}
