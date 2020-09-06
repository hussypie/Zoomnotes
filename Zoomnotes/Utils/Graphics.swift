//
//  Clamp.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
    return max(lower, min(value, upper))
}

func zoomOffset(in view: UIView, for note: NoteModel.NoteLevel) -> CGPoint {
    CGPoint(x: view.frame.midX - note.frame.midX,
            y: view.frame.midY - note.frame.midY)
}

func zoomDownTransform(at scale: CGFloat, for offset: CGPoint) -> CGAffineTransform {
    let t: CGFloat = (scale - 1) / 3

    let translateTransform = CGAffineTransform(translationX: offset.x * t,
                                               y: offset.y * t)

    /// https://medium.com/@benjamin.botto/zooming-at-the-mouse-coordinates-with-affine-transformations-86e7312fd50b
    return CGAffineTransform(translationX: offset.x, y: offset.y)
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        .concatenating(CGAffineTransform(translationX: -offset.x, y: -offset.y))
        .concatenating(translateTransform)
}

func distance(from: CGRect, to: CGRect) -> CGPoint {
    return CGPoint(x: CGFloat(from.midX - to.midX),
                   y: CGFloat(from.midY - to.midY))
}
