//
//  ZoomDownTransitionAnimator.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 05..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class ZoomDownTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let destinationRect: CGRect
    private let duration: TimeInterval = 0.2

    init(destinationRect: CGRect) {
        self.destinationRect = destinationRect
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) else {
            return
        }

        guard let fromVC = transitionContext.viewController(forKey: .from) else {
            return
        }

        let dist = distance(from: fromVC.view.bounds, to: destinationRect)

        let container = transitionContext.containerView

        container.addSubview(fromVC.view)
        fromVC.view.layoutIfNeeded()
        container.transform = zoomDownTransform(at: 1, for: dist)

        UIView.animate(withDuration: self.duration, animations: {
            container.transform = zoomDownTransform(at: 4, for: dist)
        }, completion: { _ in
            container.transform = .identity
            container.addSubview(toVC.view)
            toVC.view.layoutIfNeeded()
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
        })
    }
}
