//
//  DocumentAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

protocol DocumentAccess {
    func read(id: UUID) throws -> FileVM?
    func noteModel(of id: UUID) throws -> NoteModel?
    func updateLastModified(of file: UUID, with date: Date) throws
    func updateData(of file: UUID, with data: String) throws
    func updatePreviewImage(of file: FileVM, with image: UIImage) throws
    func updateName(of file: UUID, to name: String) throws
}
