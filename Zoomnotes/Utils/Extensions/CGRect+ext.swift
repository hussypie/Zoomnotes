//
//  CGRect+center.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

enum Half {
    case left
    case right

    var opposite: Half {
        switch self {
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}

extension CGRect {
    func half(of point: CGPoint) -> Half {
        assert(point.x >= self.minX)
        assert(point.x <= self.maxX)
        assert(point.y >= self.minY)
        assert(point.y <= self.maxY)

        if point.x < self.midX {
            return .left
        }
        return .right
    }
}

extension CGRect {
    static func from(_ store: RectStore) -> CGRect {
        CGRect(x: CGFloat(store.x),
               y: CGFloat(store.y),
               width: CGFloat(store.width),
               height: CGFloat(store.height))
    }
}
