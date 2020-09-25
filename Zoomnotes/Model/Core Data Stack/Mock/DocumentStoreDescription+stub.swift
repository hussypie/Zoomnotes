//
//  DocumentStoreDescription+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension DocumentStoreDescription {
    private static let stubImages: [UIImage] = [.actions, .checkmark, .remove, .add]
    private static let stubNames: [String] = ["Cats", "Dogs", "Unit tests"]

    static func stub(data: String) -> DocumentStoreDescription {
        return DocumentStoreDescription(data: data,
                                            id: UUID(),
                                            lastModified: Date(),
                                            name: stubNames.randomElement()!,
                                            thumbnail: stubImages.randomElement()!)
    }
}
