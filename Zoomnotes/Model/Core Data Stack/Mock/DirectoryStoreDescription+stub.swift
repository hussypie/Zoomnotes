//
//  DirectoryStoreDescription+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

extension DirectoryStoreDescription {
    private static let stubNames: [String] =
        [ "Cats", "Dogs", "Unit tests", "CRDTs", "Music", "Downloads"]

    static var stub: DirectoryStoreDescription {
        let someTimeInThePast = Date().addingTimeInterval(-Double.random(in: 0..<10000))
        return DirectoryStoreDescription(id: UUID(),
                                         created: someTimeInThePast,
                                         name: stubNames.randomElement()!,
                                         documents: [],
                                         directories: [])
    }

    static func stub(documents: [DocumentStoreDescription],
                     directories: [DirectoryStoreDescription]
    ) -> DirectoryStoreDescription {
        let someTimeInThePast = Date().addingTimeInterval(-Double.random(in: 0..<10000))
        return DirectoryStoreDescription(id: UUID(),
                                         created: someTimeInThePast,
                                         name: stubNames.randomElement()!,
                                         documents: documents,
                                         directories: directories)
    }
}
