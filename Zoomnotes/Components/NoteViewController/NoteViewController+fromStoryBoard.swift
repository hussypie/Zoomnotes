//
//  NoteViewController+fromStoryBoard.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 31..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension NoteViewController {
    static func from(_ storyboard: UIStoryboard?) -> NoteViewController? {
        return storyboard?.instantiateViewController(withIdentifier: String(describing: NoteViewController.self)) as? NoteViewController
    }
}
