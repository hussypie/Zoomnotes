//
//  CGRect+Quadrant.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 07..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

enum Half {
    case left
    case right
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
