//
//  Types.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 12..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

protocol NoteError: Error { }

protocol NoteEntity { }

struct NoteLevel: NoteEntity { private init() {} }
struct NoteImage: NoteEntity { private init() {} }

struct Directory: NoteEntity { private init() {} }
struct Document: NoteEntity { private init() {} }

typealias NoteLevelID = ID<NoteLevel>
typealias NoteImageID = ID<NoteImage>

typealias DirectoryID = ID<Directory>
typealias DocumentID = ID<Document>
