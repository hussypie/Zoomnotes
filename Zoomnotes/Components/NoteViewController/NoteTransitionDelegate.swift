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
    let interactionController: UIPercentDrivenInteractiveTransition

    override init() {
        self.interactionController = UIPercentDrivenInteractiveTransition()
        super.init()
    }

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .pop:
            return nil // ZoomTransitionAnimator(with: viewModel)
        case .push:
            return nil // ZoomDownTransition
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }

    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController
    }
}
