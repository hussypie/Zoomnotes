//
//  Publisher+sink3.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 16..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import Combine

extension Publisher {
    func sink(receiveDone: @escaping () -> Void,
              receiveError: @escaping (Self.Failure) -> Void,
              receiveValue:  @escaping (Self.Output) -> Void) -> AnyCancellable {
        return self.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    receiveDone()
                case .failure(let error):
                    receiveError(error)
                }
        },
            receiveValue: receiveValue)
    }
}
