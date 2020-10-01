//
//  ZoomTransitionAnimator.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class ZoomTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let note: NoteChildVM
    private let duration: TimeInterval = 0.2

    init(with note: NoteChildVM) {
        self.note = note
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) else { return }

        let container = transitionContext.containerView
        container.addSubview(toVC.view)

        toVC.view.frame = transitionContext.finalFrame(for: toVC)
        toVC.view.layoutIfNeeded()
        toVC.view.transform = zoomDownTransform(at: 4, for: distance(from: toVC.view.bounds, to: note.frame))

        UIView.animate(withDuration: self.duration, animations: {
            toVC.view.transform = .identity
        }, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
        })
    }
}
