//
//  Logevents.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

enum LogEvent {
    case cannotFindDirectory(id: DirectoryID)
    case cannotFindDocument(id: DocumentID)

    var message: String {
        get {
            switch self {
            case .cannotFindDirectory(id: let id):
                return "Cannot find directory (id: \(id)) in DB"
            case .cannotFindDocument(id: let id):
                return "Cannot find document (id: \(id)) in DB"
            }
        }
    }
}
