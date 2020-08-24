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
        let id: UUID
        var data: NoteData
        var children: [UUID : NoteLevel]
        var previewImage: NoteImage
        var frame: CGRect
        
        init(data: NoteData, children: [UUID : NoteLevel], preview: UIImage, frame: CGRect) {
            self.id = UUID()
            self.data = data
            self.children = children
            self.previewImage = NoteImage(wrapping: preview)
            self.frame = frame
        }
        
        static func `default`(preview: UIImage, frame: CGRect) -> NoteLevel {
            NoteLevel(data: NoteData.default, children: [:], preview: preview, frame: frame)
        }
    }
    
    class NoteData : Codable {
        var drawing: PKDrawing
        var images: [UUID : NoteImage]
        
        init(drawing: PKDrawing, images: [UUID : NoteImage]) {
            self.drawing = drawing
            self.images = images
        }
        
        func updateDrawing(with drawing: PKDrawing) {
            self.drawing = drawing
        }
        
        static var `default`: NoteData {
            NoteData(drawing: PKDrawing(), images: [:])
        }
    }
    
    let id: UUID
    private(set) var title: String
    private(set) var root: NoteLevel
    private(set) var currentLevel: NoteLevel
    
    var preview: UIImage {
        get {
            self.root.previewImage.image
        }
    }
    
    var updateDrawingCallback: ((PKDrawing) -> Void)? = nil
    
    private enum CodingKeys: String, CodingKey {
        case title, root, currentLevel, id
    }

    init(title: String, root: NoteLevel) {
        self.id = UUID()
        self.title = title
        self.root = root
        self.currentLevel = root
    }
    
    func updateDrawing(with drawing: PKDrawing) {
        self.currentLevel.data.updateDrawing(with: drawing)
        if self.currentLevel.id == self.root.id {
            self.updateDrawingCallback?(self.root.data.drawing)
        }
    }
    
    func updatePreview(with image: UIImage) {
        self.currentLevel.previewImage = NoteImage(wrapping: image)
    }
    
    func add(subLevel: NoteLevel) {
        self.currentLevel.children[subLevel.id] = subLevel
    }
    
    func remove(subLevel id: UUID) {
        self.currentLevel.children.removeValue(forKey: id)
    }
    
    static func `default`(image: UIImage, frame: CGRect) -> NoteModel {
        NoteModel(title: "Untitled", root: NoteLevel.default(preview: image, frame: frame))
    }
}
