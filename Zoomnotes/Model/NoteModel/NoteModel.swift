//
//  NoteModel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit
import Combine

class NoteModel: Codable {
    class NoteLevel: NSObject, Codable {
        let id: UUID
        var data: NoteData
        var children: [UUID: NoteLevel]
        var previewImage: CodableImage
        var frame: CGRect

        required init(data: NoteData, children: [UUID: NoteLevel], preview: UIImage, frame: CGRect) {
            self.id = UUID()
            self.data = data
            self.children = children
            self.previewImage = CodableImage(wrapping: preview)
            self.frame = frame
        }

        static func `default`(preview: UIImage, frame: CGRect) -> NoteLevel {
            NoteLevel(data: NoteData.default, children: [:], preview: preview, frame: frame)
        }
    }

    class NoteData: Codable {
        var drawing: PKDrawing
        var images: [UUID: CodableImage]

        init(drawing: PKDrawing, images: [UUID: CodableImage]) {
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
    var title: String
    private(set) var root: NoteLevel

    var preview: UIImage {
        self.root.previewImage.image
    }

    init(title: String, root: NoteLevel) {
        self.id = UUID()
        self.title = title
        self.root = root
    }

    static func `default`(image: UIImage, frame: CGRect) -> NoteModel {
        NoteModel(title: "Untitled", root: NoteLevel.default(preview: image, frame: frame))
    }
}

extension NoteModel {
    func serialize(done: @escaping (String) -> Void, error: @escaping (Error) -> Void) {
        let encoder = JSONEncoder()
        DispatchQueue.main.async {
            do {
                let json = try encoder.encode(self)
                let jsonString = String(data: json, encoding: String.Encoding.utf8)

                assert(jsonString != nil)
                done(jsonString!)
            } catch let err {
                error(err)
            }
        }
    }

    static func from(json string: String, done: @escaping (NoteModel) -> Void, error: @escaping (Error) -> Void) {
        let decoder = JSONDecoder()
        DispatchQueue.main.async {
            do {
                let data = string.data(using: .utf8)
                assert(data != nil)
                let note = try decoder.decode(NoteModel.self, from: data!)
                done(note)
            } catch let err {
                error(err)
            }
        }
    }
}

extension NoteModel {
    static var stub: NoteModel {
        return NoteModel.default(image: .checkmark, frame: CGRect(x: 0, y: 0, width: 200, height: 300))
    }
}
