//
//  AlertController+closure.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 09..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension UIAlertController {
    static func withActions(title: String?,
                            message: String?,
                            style: UIAlertController.Style,
                            items: (UIAlertController) -> [UIAlertAction]) -> UIAlertController {
        let controller = UIAlertController(title: title, message: message, preferredStyle: style)
        let actions = items(controller)
        actions.forEach { controller.addAction($0) }
        return controller
    }
}
