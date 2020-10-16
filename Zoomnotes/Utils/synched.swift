//
//  syched.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 16..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

func synced(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}
