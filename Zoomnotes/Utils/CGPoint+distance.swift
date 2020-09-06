//
//  CGPoint+distance.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension CGPoint {

    func distance(to: CGPoint) -> CGPoint {
        return CGPoint(x: CGFloat(self.midX - to.midX),
                       y: CGFloat(self.midY - to.midY))
    }
}
