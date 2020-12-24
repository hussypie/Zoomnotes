//
//  Iffn.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 30..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

func `if`<T>(
    _ test: @autoclosure () -> Bool,
    then: () -> T,
    else: () -> T
) -> T {
    if test() {
        return then()
    } else {
        return `else`()
    }
}
