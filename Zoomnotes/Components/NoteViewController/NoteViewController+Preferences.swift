//
//  NoteViewController+Preferences.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 07..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension NoteViewController {
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    override var prefersStatusBarHidden: Bool {
        return UserDefaults.standard.withDefault(.statusBarVisible, default: true)
    }
}
