//
//  NoteModel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit

class NoteModel : Codable {
    class NoteLevel : Codable {
        let data: NoteData
        let children: [NoteLevel]
        
        init(data: NoteData, children: [NoteLevel]) {
            self.data = data
            self.children = children
        }
        
        static var `default`: NoteLevel {
            NoteLevel(data: NoteData.default, children: [])
        }
    }
    
    class NoteData : Codable {
        var drawing: PKDrawing
        var images: [NoteImage]
        
        init(drawing: PKDrawing, images: [NoteImage]) {
            self.drawing = drawing
            self.images = images
        }
        
        func updateDrawing(with drawing: PKDrawing) {
            self.drawing = drawing
        }
        
        static var `default`: NoteData {
            NoteData(drawing: PKDrawing(), images: [])
        }
    }
    
    var title: String
    var root: NoteLevel
    
    var currentLevel: NoteLevel

    init(title: String, root: NoteLevel) {
        self.title = title
        self.root = root
        self.currentLevel = root
    }
    
    func updateDrawing(with drawing: PKDrawing) {
        self.currentLevel.data.updateDrawing(with: drawing)
    }
    
    static func `default`(controller: DataModelController) -> NoteModel {
        NoteModel(title: "Untitled", root: NoteLevel.default)
    }
}
