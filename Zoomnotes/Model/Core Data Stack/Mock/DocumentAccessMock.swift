//
//  DocumentAccessMock.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class DocumentAccessMock: DocumentAccess {
    func read(id: UUID) throws -> FileVM? {
        return nil
    }

    func noteModel(of id: UUID) throws -> NoteLevelDescription? {
        return nil
    }

    func updateLastModified(of file: UUID, with date: Date) throws {
    }

    func updatePreviewImage(of file: FileVM, with image: UIImage) throws {
    }

    func updateName(of file: UUID, to name: String) throws {
    }

    func delete(_ file: UUID) throws {
    }
}
