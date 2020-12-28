//
//  ObservedValue.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 12. 28..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import Combine

struct ObservedValue<T> {
    typealias UpdateFn = (T) -> Void
    let publisher: AnyPublisher<T, Never>
    let update: UpdateFn
}
