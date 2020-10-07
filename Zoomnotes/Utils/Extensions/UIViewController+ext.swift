//
//  UIViewController+ext.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 07..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    static func from(_ storyboard: UIStoryboard?) -> Self? {
        return storyboard?.instantiateViewController(withIdentifier: String(describing: Self.self)) as? Self
    }

    func capture(_ view: UIView, prepare: () -> Void, done: () -> Void) -> UIImage {
        prepare()
        UIGraphicsBeginImageContext(view.frame.size)
        let context = UIGraphicsGetCurrentContext()!
        view.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        done()
        return image
    }
}
