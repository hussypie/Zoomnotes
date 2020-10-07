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
    let sourceRect: CGRect?
    var destinationRect: CGRect?
    private let interactionController: UIPercentDrivenInteractiveTransition

    init(source: CGRect?) {
        self.interactionController = UIPercentDrivenInteractiveTransition()
        self.sourceRect = source
        self.destinationRect = nil
        super.init()
    }

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .pop:
            guard let source = self.sourceRect else {
                return nil
            }
            self.interactionController.update(0)
            return ZoomUpTransitionAnimator(with: source)
        case .push:
            guard let dest = destinationRect else { return nil }
            self.interactionController.update(0)
            return ZoomDownTransitionAnimator(destinationRect: dest)
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }

    func set(destination: CGRect) {
        self.destinationRect = destination
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

    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController
    }
}
